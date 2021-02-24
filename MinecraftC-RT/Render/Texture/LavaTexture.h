#pragma once
#include "AnimatedTexture.h"

typedef AnimatedTexture LavaTexture;

typedef struct LavaTextureData
{
	float4 Colors[256];
} * LavaTextureData;

LavaTexture LavaTextureCreate(void);
void LavaTextureAnimate(LavaTexture texture);
void LavaTextureDestroy(LavaTexture texture);
