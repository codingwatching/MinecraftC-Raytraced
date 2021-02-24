#pragma once
#include "Utilities/LinearMath.h"

typedef struct MovingObjectPosition
{
	int EntityPosition;
	int3 XYZ;
	int Face;
	float3 Vector;
	bool Null;
} MovingObjectPosition;
