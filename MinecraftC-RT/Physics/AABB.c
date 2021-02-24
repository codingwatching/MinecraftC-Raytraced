#include "AABB.h"
#include "Vector3D.h"

static float Epsilon = 0.0;

AABB AABBExpand(AABB c, float3 a)
{
	c.V0.x += a.x < 0.0 ? a.x : 0.0;
	c.V0.y += a.y < 0.0 ? a.y : 0.0;
	c.V0.z += a.z < 0.0 ? a.z : 0.0;
	c.V1.x += a.x > 0.0 ? a.x : 0.0;
	c.V1.y += a.y > 0.0 ? a.y : 0.0;
	c.V1.z += a.z > 0.0 ? a.z : 0.0;
	return c;
}

AABB AABBGrow(AABB c, float3 a)
{
	return (AABB){ .V0 = c.V0 - a, .V1 = c.V1 + a };
}

AABB AABBMove(AABB c, float3 a)
{
	return (AABB){ .V0 = c.V0 + a, .V1 = c.V1 + a };
}

float AABBClipXCollide(AABB c0, AABB c1, float xa)
{
	if (c1.V1.y > c0.V0.y && c1.V0.y < c0.V1.y)
	{
		if (c1.V1.z > c0.V0.z && c1.V0.z < c0.V1.z)
		{
			float max = c0.V0.x - c1.V1.x - Epsilon;
			if (xa > 0.0 && c1.V1.x <= c0.V0.x && max < xa) { xa = max; }
			max = c0.V1.x - c1.V0.x + Epsilon;
			if (xa < 0.0 && c1.V0.x >= c0.V1.x && max > xa) { xa = max; }
			return xa;
		}
		else { return xa; }
	}
	else { return xa; }
}

float AABBClipYCollide(AABB c0, AABB c1, float ya)
{
	if (c1.V1.x > c0.V0.x && c1.V0.x < c0.V1.x)
	{
		if (c1.V1.z > c0.V0.z && c1.V0.z < c0.V1.z)
		{
			float max = c0.V0.y - c1.V1.y - Epsilon;
			if (ya > 0.0 && c1.V1.y <= c0.V0.y && max < ya) { ya = max; }
			max = c0.V1.y - c1.V0.y + Epsilon;
			if (ya < 0.0 && c1.V0.y >= c0.V1.y && max > ya) { ya = max; }
			return ya;
		}
		else { return ya; }
	}
	else { return ya; }
}

float AABBClipZCollide(AABB c0, AABB c1, float za)
{
	if (c1.V1.x > c0.V0.x && c1.V0.x < c0.V1.x)
	{
		if (c1.V1.y > c0.V0.y && c1.V0.y < c0.V1.y)
		{
			float max = c0.V0.z - c1.V1.z - Epsilon;
			if (za > 0.0 && c1.V1.z <= c0.V0.z && max < za) { za = max; }
			max = c0.V1.z - c1.V0.z + Epsilon;
			if (za < 0.0 && c1.V0.z >= c0.V1.z && max > za) { za = max; }
			return za;
		}
		else { return za; }
	}
	else { return za; }
}

bool AABBIntersects(AABB c0, AABB c1)
{
	return c1.V1.x > c0.V0.x && c1.V0.x < c0.V1.x ? (c1.V1.y > c0.V0.y && c1.V0.y < c0.V1.y ? c1.V1.z > c0.V0.z && c1.V0.z < c0.V1.z : false) : false;
}

bool AABBIntersectsInner(AABB c0, AABB c1)
{
	return c1.V1.x >= c0.V0.x && c1.V0.x <= c0.V1.x ? (c1.V1.y >= c0.V0.y && c1.V0.y <= c0.V1.y ? c1.V1.z >= c0.V0.z && c1.V0.z <= c0.V1.z : false) : false;
}

bool AABBContainsPoint(AABB c, float3 p)
{
	return p.x > c.V0.x && p.x < c.V1.x ? (p.y > c.V0.y && p.y < c.V1.y ? p.z > c.V0.z && p.z < c.V1.z : false) : false;
}

float AABBGetSize(AABB c)
{
	float3 d = c.V1 - c.V0;
	return (d.x + d.y + d.z) / 3.0;
}

AABB AABBShrink(AABB c, float3 a)
{
	c.V0.x -= a.x < 0.0 ? a.x : 0.0;
	c.V0.y -= a.y < 0.0 ? a.y : 0.0;
	c.V0.z -= a.z < 0.0 ? a.z : 0.0;
	c.V1.x -= a.x > 0.0 ? a.x : 0.0;
	c.V1.y -= a.y > 0.0 ? a.y : 0.0;
	c.V1.z -= a.z > 0.0 ? a.z : 0.0;
	return c;
}

static bool XIntersects(AABB c, float3 v)
{
	return Vector3DIsNull(v) ? false : v.y >= c.V0.y && v.y <= c.V1.y && v.z >= c.V0.z && v.z <= c.V1.z;
}

static bool YIntersects(AABB c, float3 v)
{
	return Vector3DIsNull(v) ? false : v.x >= c.V0.x && v.x <= c.V1.x && v.z >= c.V0.z && v.z <= c.V1.z;
}

static bool ZIntersects(AABB c, float3 v)
{
	return Vector3DIsNull(v) ? false : v.x >= c.V0.x && v.x <= c.V1.x && v.y >= c.V0.y && v.y <= c.V1.y;
}

MovingObjectPosition AABBClip(AABB c, float3 v1, float3 v2)
{
	float3 f0 = Vector3DGetXIntersection(v1, v2, c.V0.x);
	float3 f1 = Vector3DGetXIntersection(v1, v2, c.V1.x);
	float3 f2 = Vector3DGetYIntersection(v1, v2, c.V0.y);
	float3 f3 = Vector3DGetYIntersection(v1, v2, c.V1.y);
	float3 f4 = Vector3DGetZIntersection(v1, v2, c.V0.z);
	float3 f5 = Vector3DGetZIntersection(v1, v2, c.V1.z);
	if (!XIntersects(c, f0)) { f0 = Vector3DNull; }
	if (!XIntersects(c, f1)) { f1 = Vector3DNull; }
	if (!YIntersects(c, f2)) { f2 = Vector3DNull; }
	if (!YIntersects(c, f3)) { f3 = Vector3DNull; }
	if (!ZIntersects(c, f4)) { f4 = Vector3DNull; }
	if (!ZIntersects(c, f5)) { f5 = Vector3DNull; }
	float3 f6 = Vector3DNull;
	if (!Vector3DIsNull(f0)) { f6 = f0; }
	if (!Vector3DIsNull(f1) && (Vector3DIsNull(f6) || sqdistance3f(v1, f1) < sqdistance3f(v1, f6))) { f6 = f1; }
	if (!Vector3DIsNull(f2) && (Vector3DIsNull(f6) || sqdistance3f(v1, f2) < sqdistance3f(v1, f6))) { f6 = f2; }
	if (!Vector3DIsNull(f3) && (Vector3DIsNull(f6) || sqdistance3f(v1, f3) < sqdistance3f(v1, f6))) { f6 = f3; }
	if (!Vector3DIsNull(f4) && (Vector3DIsNull(f6) || sqdistance3f(v1, f4) < sqdistance3f(v1, f6))) { f6 = f4; }
	if (!Vector3DIsNull(f5) && (Vector3DIsNull(f6) || sqdistance3f(v1, f5) < sqdistance3f(v1, f6))) { f6 = f5; }
	if (Vector3DIsNull(f6)) { return (MovingObjectPosition){ .Null = true }; }
	int face = -1;
	if (f6.x == f0.x && f6.y == f0.y && f6.z == f0.z) { face = 4; }
	if (f6.x == f1.x && f6.y == f1.y && f6.z == f1.z) { face = 5; }
	if (f6.x == f2.x && f6.y == f2.y && f6.z == f2.z) { face = 0; }
	if (f6.x == f3.x && f6.y == f3.y && f6.z == f3.z) { face = 1; }
	if (f6.x == f4.x && f6.y == f4.y && f6.z == f4.z) { face = 2; }
	if (f6.x == f5.x && f6.y == f5.y && f6.z == f5.z) { face = 3; }
	return (MovingObjectPosition){ .Face = face, .Vector = f6 };
}

bool AABBIsNull(AABB c)
{
	return c.V0.x == 0.0 && c.V0.y == 0.0 && c.V0.z == 0.0 && c.V1.x == 0.0 && c.V1.y == 0.0 && c.V1.z == 0.0;
}

