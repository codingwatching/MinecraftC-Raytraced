#include "Octree.h"
#include "Level.h"

Octree OctreeCreate(Level level)
{
	Octree tree = MemoryAllocate(sizeof(struct Octree));
	*tree = (struct Octree)
	{
		.Level = level,
		.Depth = log2(fmax(level->Width, fmax(level->Height, level->Depth))),
	};
	tree->MaskCount = ((int)pow(8, tree->Depth) - 1) / 7;
	tree->Masks = MemoryAllocate(tree->MaskCount);
	return tree;
}

void OctreeSet(Octree tree, int x, int y, int z, BlockType tile)
{
	if (x < 0 || y < 0 || z < 0 || x >= tree->Level->Width || y >= tree->Level->Depth || z >= tree->Level->Height) { return; }
	int start = 0, offset = 0;
	int3 base = { 0 };
	int mid = pow(2, tree->Depth - 1);
	unsigned char qStack[tree->Depth];
	int indexStack[tree->Depth];
	for (int i = 0; i < tree->Depth; i++)
	{
		unsigned char mask = tree->Masks[start + offset];
		unsigned int q = (x >= base.x + mid) + 2 * (y >= base.y + mid) + 4 * (z >= base.z + mid);
		if (tile == BlockTypeNone && ((mask >> q) & 1) == 0) { break; }
		if (((mask >> q) & 1) == 0) { tree->Masks[start + offset] ^= (1 << q); }
		
		qStack[i] = q;
		indexStack[i] = start + offset;
		offset = 8 * offset + q;
		start += pow(8, i);
		base += mid * ((q >> (int3){ 0, 1, 2 }) & 1);
		mid /= 2;
		
		if (i == tree->Depth - 1 && tile == BlockTypeNone)
		{
			for (int j = i; j >= 0; j--)
			{
				tree->Masks[indexStack[j]] ^= (1 << qStack[j]);
				if (tree->Masks[indexStack[j]] > 0) { break; }
			}
		}
	}
}

BlockType OctreeGet(Octree tree, int x, int y, int z)
{
	if (x < 0 || y < 0 || z < 0 || x >= tree->Level->Width || y >= tree->Level->Depth || z >= tree->Level->Height) { return BlockTypeNone; }
	int start = 0, offset = 0;
	int3 base = { 0 };
	int mid = pow(2, tree->Depth - 1);
	for (int i = 0; i < tree->Depth; i++)
	{
		unsigned char mask = tree->Masks[start + offset];
		unsigned int q = (x >= base.x + mid) + 2 * (y >= base.y + mid) + 4 * (z >= base.z + mid);
		if (((mask >> q) & 1) == 0) { return BlockTypeNone; }
		offset = 8 * offset + q;
		start += pow(8, i);
		base += mid * ((q >> (int3){ 0, 1, 2 }) & 1);
		mid /= 2;
		if (i == tree->Depth - 1) { return LevelGetTile(tree->Level, x, y, z); }
	}
	return BlockTypeNone;
}

void OctreeDestroy(Octree tree)
{
	MemoryFree(tree->Masks);
	MemoryFree(tree);
}
