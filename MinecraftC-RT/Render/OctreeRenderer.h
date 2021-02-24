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
	cl_mem TextureBuffer;
	unsigned int TextureID;
	unsigned int * TextureData;
	Octree Octree;
} extern OctreeRenderer;

void OctreeRendererInitialize(int width, int height);
void OctreeRendererSetOctree(Octree tree);
void OctreeRendererDeinitialize(void);
