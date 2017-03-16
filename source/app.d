module app;

import avocado.core;
import avocado.dfs;
import avocado.assimp;
import avocado.gl3;
import avocado.sdl2;

import components;
import systems.display;
import systems.logic;
import trackgen;

alias View = SDLWindow;
alias Renderer = GL3Renderer;
alias Shader = GL3ShaderProgram;
alias ShaderUnit = GLShaderUnit;
alias Texture = GLTexture;

alias Mesh = GL3MeshIndexPositionTextureNormal;

Mesh convertAssimpMesh(AssimpMeshData from)
{
	auto mesh = new GL3MeshIndexPositionTextureNormal();
	mesh.primitiveType = PrimitiveType.Triangles;
	foreach (indices; from.indices)
		mesh.addIndexArray(indices);
	mesh.addPositionArray(from.vertices);
	if (from.texCoords.length)
	{
		foreach (texCoord; from.texCoords[0])
			mesh.addTexCoord(texCoord.xy);
	}
	else
	{
		foreach (vertex; from.vertices)
			mesh.addTexCoord(vertex.xy);
	}
	mesh.addNormalArray(from.normals);
	mesh.generate();
	return mesh;
}

void main()
{
	auto engine = new Engine;
	with (engine)
	{
		auto window = new View("Fluffy");
		auto renderer = new Renderer;
		auto world = add(window, renderer);

		void onResized(int width, int height)
		{
			renderer.resize(width, height);
		}

		window.onResized ~= &onResized;
		onResized(window.width, window.height);

		auto resources = new ResourceManager();
		resources.prepend("res");
		resources.prependAll("packs", "*.{pack,zip}");

		auto shader = new Shader();
		shader.attach(new ShaderUnit(ShaderType.Fragment,
				resources.load!TextProvider("shaders/default.frag").value));
		shader.attach(new ShaderUnit(ShaderType.Vertex,
				resources.load!TextProvider("shaders/default.vert").value));
		shader.create(renderer);
		shader.register(["modelview", "projection", "tex"]);
		shader.set("tex", 0);

		renderer.setupDepthTest(DepthFunc.Less);

		world.addSystem!LogicSystem(renderer, window);
		world.addSystem!DisplaySystem(renderer, window);

		auto test = resources.load!Texture("textures/test.png");
		auto vehicle1 = resources.load!Texture("textures/vehicle1.png");
		{
			auto mesh = resources.load!Scene("models/vehicle1.obj").value.meshes[0].convertAssimpMesh;
			mixin(createEntity!("Player", q{
				EntityDisplay: mesh, shader, vehicle1, mat4.identity
				Transformation: mat4.translation(0, 0, 0)
				PlayerControls: Key.Up, Key.Left, Key.Down, Key.Right
				VehiclePhysics:
			}));
		}
		{
			auto track = generateTrack;
			mixin(createEntity!("Track", q{
				EntityDisplay: track.mesh, shader, test, mat4.identity
				Transformation: mat4.translation(0, 0, 0)
				TrackCollision: track.outerRing, track.innerRing
			}));
		}

		FPSLimiter limiter = new FPSLimiter(120);

		start();
		while (update)
			limiter.wait();
		stop();
	}
}
