#pragma once
#include "Tile/Block.h"

typedef struct Octree
{
	int Depth;
	int MaskCount;
	unsigned char * Masks;
	struct Level * Level;
} * Octree;

Octree OctreeCreate(struct Level * level);
void OctreeSet(Octree tree, int x, int y, int z, BlockType tile, bool updateBuffer);
BlockType OctreeGet(Octree tree, int x, int y, int z);
void OctreeDestroy(Octree tree);
