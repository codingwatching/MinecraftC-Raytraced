#pragma once
#include <OpenCL.h>
#include "../Level/Octree.h"
#include "../Utilities/LinearMath.h"

struct OctreeRenderer
{
	int Width, Height;
	cl_device_id Device;
	cl_context Context;
	cl_program Shader;
	cl_kernel Kernel;
	cl_command_queue Queue;
	cl_mem OctreeBuffer, BlockBuffer;
	cl_mem OutputTexture;
	cl_mem TerrainTexture;
	unsigned int TextureID;
	Octree Octree;
	TextureManager TextureManager;
} extern OctreeRenderer;

void OctreeRendererInitialize(TextureManager textures, int width, int height);
void OctreeRendererResize(int width, int height);
void OctreeRendererSetOctree(Octree tree);
void OctreeRendererEnqueue(float dt, float fps);
void OctreeRendererDeinitialize(void);
