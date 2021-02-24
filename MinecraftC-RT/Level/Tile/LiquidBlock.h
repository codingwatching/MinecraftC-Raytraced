#pragma once
#include "Block.h"

typedef Block LiquidBlock;

typedef struct LiquidBlockData
{
	LiquidType Type;
	BlockType StillID;
	BlockType MovingID;
} * LiquidBlockData;

LiquidBlock LiquidBlockCreate(BlockType blockType, LiquidType liquidType);
bool LiquidBlockIsCube(LiquidBlock block);
void LiquidBlockOnPlaced(LiquidBlock block, struct Level * level, int x, int y, int z);
void LiquidBlockUpdate(LiquidBlock block, struct Level * level, int x, int y, int z, RandomGenerator random);
float LiquidBlockGetBrightness(LiquidBlock block, struct Level * level, int x, int y, int z);
bool LiquidBlockCanRenderSide(LiquidBlock block, struct Level * level, int x, int y, int z, int side);
void LiquidBlockRenderInside(LiquidBlock block, int x, int y, int z, int side);
AABB LiquidBlockGetSelectionAABB(LiquidBlock block, int x, int y, int z);
bool LiquidBlockIsOpaque(LiquidBlock block);
bool LiquidBlockIsSolid(LiquidBlock block);
LiquidType LiquidBlockGetLiquidType(LiquidBlock block);
void LiquidBlockOnNeighborChanged(LiquidBlock block, struct Level * level, int x, int y, int z, BlockType tile);
int LiquidBlockGetTickDelay(LiquidBlock block);
void LiquidBlockOnBreak(LiquidBlock block, struct Level * level, int x, int y, int z);
void LiquidBlockDropItems(LiquidBlock block, struct Level * level, int x, int y, int z, float probability);
int LiquidBlockGetDropCount(LiquidBlock block);
int LiquidBlockGetRenderPass(LiquidBlock block);
void LiquidBlockDestroy(LiquidBlock block);
