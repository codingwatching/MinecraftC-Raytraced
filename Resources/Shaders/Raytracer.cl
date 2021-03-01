#define BlockTypeGrass 2
#define BlockTypeSapling 6
#define BlockTypeBedrock 7
#define BlockTypeWater 8
#define BlockTypeStillWater 9
#define BlockTypeLog 17
#define BlockTypeLeaves 18
#define BlockTypeGlass 20
#define BlockTypeDandelion 37
#define BlockTypeRose 38
#define BlockTypeBrownMushroom 39
#define BlockTypeRedMushroom 40
#define BlockTypeGold 41
#define BlockTypeIron 42
#define BlockTypeDoubleSlab 43
#define BlockTypeSlab 44
#define BlockTypeTNT 46
#define BlockTypeBookshelf 47

const sampler_t TerrainSampler = CLK_NORMALIZED_COORDS_TRUE | CLK_ADDRESS_REPEAT | CLK_FILTER_NEAREST;

constant int TextureIDTable[256] = { 0, 2, 0, 3, 17, 5, 16, 17, 15, 15, 31, 31, 19, 20, 33, 34, 35, 0, 23, 49, 50, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 14, 13, 30, 29, 41, 40, 0, 0, 8, 0, 0, 37, 38 };

float3 MatrixTransformPoint(float16 l, float3 r)
{
	return (float3)
	{
		r.x * l.s0 + r.y * l.s4 + r.z * l.s8 + l.sC,
		r.x * l.s1 + r.y * l.s5 + r.z * l.s9 + l.sD,
		r.x * l.s2 + r.y * l.s6 + r.z * l.sA + l.sE,
	};
}

void RayBox(float3 r, float3 o, float3 bmin, float3 bmax, float * enter, float * exit)
{
	float3 inv = 1.0f / r;
	float3 t1 = (bmin - o) * inv;
	float3 t2 = (bmax - o) * inv;
	float3 tn = fmin(t1, t2);
	float3 tf = fmax(t1, t2);
	*enter = fmax(tn.x, fmax(tn.y, tn.z));
	*exit = fmin(tf.x, fmin(tf.y, tf.z));
}

bool RayBoxIntersection(float3 r, float3 o, float3 bmin, float3 bmax, float * dist)
{
	float n, f;
	RayBox(r, o, bmin, bmax, &n, &f);
	*dist = n;
	return f > n && f > 0.0f;
}

bool RayPlaneIntersection(float3 ray, float3 origin, float height, float3 * hit)
{
	if (fabs(ray.y) != 0.0f)
	{
		float t = (height - origin.y) / ray.y;
		*hit = origin + ray * t;
		return t >= 0.0f;
	}
	return false;
}

float3 BoxNormal(float3 hit, float3 bmin, float3 bmax)
{
	return normalize(round((hit - (bmin + bmax) / 2.0f) / (fabs(bmin - bmax)) * 1.0001f));
}

int GetTextureID(uchar tile, int side)
{
	if (tile == BlockTypeGrass) { return side == 1 ? 0 : (side == 0 ? 2 : 3); }
	if (tile == BlockTypeLog) { return side == 1 ? 21 : (side == 0 ? 21 : 20); }
	if (tile == BlockTypeSlab || tile == BlockTypeDoubleSlab) { return side <= 1 ? 6 : 5; }
	if (tile == BlockTypeBookshelf) { return side <= 1 ? 4 : 35; }
	if (tile == BlockTypeGold || tile == BlockTypeIron) { return side == 1 ? TextureIDTable[tile] - 17 : (side == 0 ? TextureIDTable[tile] + 15 : TextureIDTable[tile] - 1); }
	if (tile == BlockTypeTNT) { return side == 0 ? 10 : (side == 1 ? 9 : 8); }
	if (tile == BlockTypeDandelion || tile == BlockTypeRose || tile == BlockTypeSapling || tile == BlockTypeBrownMushroom || tile == BlockTypeRedMushroom) { return side == 0 || side == 1 ? -2 : TextureIDTable[tile] - 1; }
	return TextureIDTable[tile] - 1;
}

float GetTileReflectiveness(uchar tile)
{
	if (tile == BlockTypeGlass) { return 0.0f; }
	if (tile == BlockTypeWater || tile == BlockTypeStillWater) { return 0.25f; }
	return 0.0f;
}

bool ShouldDiscardTransparency(uchar tile)
{
	return tile == BlockTypeLeaves || tile == BlockTypeDandelion || tile == BlockTypeRose || tile == BlockTypeRedMushroom || tile == BlockTypeBrownMushroom;
}

float3 BGColor(float3 ray)
{
	float t = 1.0f - (1.0f - ray.y) * (1.0f - ray.y);
	return t * (float3){ 0.63f, 0.8f, 1.0f } + (1.0f - t) * (float3){ 1.0f, 1.0f, 1.0f };
}

float4 WaterColor(float3 hit, __read_only image2d_t terrain)
{
	float2 uv = (hit - floor(hit)).xz / 16.0f + (float2){ 224.0f / 256.0f, 0.0f };
	return read_imagef(terrain, TerrainSampler, uv);
}

bool RayTreeIntersection(__global uchar * octree, __global uchar * blocks, __read_only image2d_t terrain, float3 ray, float3 origin, int treeDepth, bool ignoreWater, float time, float3 * base, float3 * hit, float3 * hitExit, uchar * tile, float3 * normal, float4 * color)
{
	*tile = 0;
	float size = pow(2.0f, (float)treeDepth);
	int sizei = 1;
	for (int i = 0; i < treeDepth; i++) { sizei *= 2; }
	float dist;
	if (!RayBoxIntersection(ray, origin, (float3){ 0.0f, 0.0f, 0.0f }, (float3){ 1.0f, 1.0f, 1.0f } * size, &dist))
	{
		*hit = ray * dist + origin;
		return false;
	}
	
	*hit = origin + fmax(dist, 0.0f) * ray;
	*color = (float4){ 0.0f, 0.0f, 0.0f, 0.0f };
	*base = (float3){ 0.0f, 0.0f, 0.0f };
	float mid = size / 2.0f;
	int level = 0;
	int offset = 0;
	int index = 1;
	while (level < treeDepth)
	{
		uchar mask = octree[(index - 1) / 7 + offset];
		uint q = (hit->x > base->x + mid) + 2 * (hit->y > base->y + mid) + 4 * (hit->z > base->z + mid);
		*base += mid * convert_float3(((uint3){ q, q, q } >> (uint3){ 0, 1, 2 }) & 1);
		
		if (((mask >> q) & 1) == 0)
		{
			float enter, exit;
			RayBox(ray, *hit, *base, *base + mid, &enter, &exit);
			//if (exit - enter < 0.004f * distance(*hit, origin)) { *tile = 255; break; }
			*hit += exit * ray + sign(ray) * 0.0001f;
			if (hit->x >= size || hit->y >= size || hit->z >= size || hit->x <= 0.0f || hit->y <= 0.0f || hit->z <= 0.0f) { return false; }
			
			*base = (float3){ 0.0f, 0.0f, 0.0f };
			mid = size / 2.0f;
			offset = 0;
			index = 1;
			level = 0;
			continue;
		}
		
		offset = 8 * offset + (int)q;

		if (level == treeDepth - 1)
		{
			int3 v = convert_int3(*base);
			if (v.x >= 0 && v.y >= 0 && v.z >= 0 && v.x < sizei && v.y < 64 && v.z < sizei)
			{
				float enter, exit;
				RayBox(ray, origin, *base, *base + mid, &enter, &exit);
				*hit = origin + ray * enter;
				*hitExit = origin + ray * exit + sign(ray) * 0.0001f;
				*tile = blocks[(v.y * sizei + v.z) * sizei + v.x];
				*normal = BoxNormal(*hit, *base, *base + mid);
				
				bool intersection = true;
				if (*tile == BlockTypeWater || *tile == BlockTypeStillWater)
				{
					uchar above = blocks[((v.y + 1) * sizei + v.z) * sizei + v.x];
					if (above != BlockTypeWater && above != BlockTypeStillWater)
					{
						float amp = 0.05f;
						float freq = 1.0f;
						base->y -= 0.05f + amp * (sin(freq * (hit->x + hit->z) + time * 1.25f) * 0.5f + 0.5f);
						RayBox(ray, origin, *base, *base + mid, &enter, &exit);
						*hit = origin + ray * enter;
						if (exit < enter || exit < 0.0f || enter < 0.0f) { intersection = false; }
						if (hit->y - base->y == 1.0f) { *normal = normalize((float3){ 0.5f * amp * freq * cos((hit->x + hit->z) * freq + time), 1.0f, 0.5f * amp * freq * cos((hit->x + hit->z) * freq + time) }); }
					}
				}
				
				float2 uv = (float2){ 0.0f, 0.0f };
				float3 norm = *hit - *base;
				int side = 0;
				if (norm.x == 0.0f) { uv = (float2){ norm.z, 1.0f - norm.y }; side = 5; }
				if (norm.x == 1.0f) { uv = (float2){ 1.0f - norm.z, 1.0 - norm.y }; side = 4; }
				if (norm.y == 0.0f) { uv = norm.xz; side = 0; }
				if (norm.y == 1.0f) { uv = norm.xz; side = 1; }
				if (norm.z == 0.0f) { uv = (float2){ 1.0f - norm.x, 1.0f - norm.y }; side = 3; }
				if (norm.z == 1.0f) { uv = (float2){ norm.x, 1.0f - norm.y }; side = 2; }
				int id = GetTextureID(*tile, side);
				uv = uv / 16.0f + (float2){ (float)((id % 16) << 4), (float)((id / 16) << 4) } / 256.0f;
				*color = read_imagef(terrain, TerrainSampler, uv);
				if (!intersection || id == -2 || (ShouldDiscardTransparency(*tile) && color->w == 0.0f) || ((*tile == BlockTypeWater || *tile == BlockTypeStillWater) && ignoreWater))
				{
					*hit = *hitExit;
					if (hit->x >= size || hit->y >= size || hit->z >= size || hit->x <= 0.0f || hit->y <= 0.0f || hit->z <= 0.0f) { return false; }
					*base = (float3){ 0.0f, 0.0f, 0.0f };
					mid = size / 2.0f;
					offset = 0;
					index = 1;
					level = 0;
					continue;
				}
				if (id == -1) { *color = (float4){ 1.0f, 0.0f, 1.0f, 1.0f }; }
				return true;
			}
			else
			{
				*tile = 0;
				return false;
			}
		}

		mid /= 2.0f;
		index *= 8;
		level++;
	}
	return false;
}

bool RaySceneIntersection(__global uchar * octree, __global uchar * blocks, __read_only image2d_t terrain, float3 ray, float3 origin, int treeDepth, bool ignoreWater, float time, float3 * base, float3 * hit, float3 * hitExit, uchar * tile, float3 * normal, float4 * color)
{
	if (!RayTreeIntersection(octree, blocks, terrain, ray, origin, treeDepth, ignoreWater, time, base, hit, hitExit, tile, normal, color))
	{
		if (RayPlaneIntersection(ray, origin, 31.9f, hit))
		{
			if (!RayPlaneIntersection(ray, *hit, 0.0f, hitExit)) { return false; }
			*tile = BlockTypeWater;
			*normal = (float3){ 0.0f, 1.0f, 0.0f };
			*color = WaterColor(*hit, terrain);
			return true;
		}
		else if (RayPlaneIntersection(ray, *hitExit, 0.0f, hit))
		{
			*hitExit = *hit + ray * 0.0001f;
			*tile = BlockTypeBedrock;
			*normal = (float3){ 0.0f, 1.0f, 0.0f };
			*color = (float4){ 0.0f, 0.0f, 0.0f, 1.0f };
			return false;
		}
		else { return false; }
	}
	else { return true; }
}

float3 TraceLighting(float3 color, float3 lightDir, float3 normal)
{
	return color * ((max(dot(lightDir, normal), 0.0f) * 0.75f + 0.25f) * (float3){ 1.0f, 0.95f, 0.8f } + (float3){ 0.2f, 0.2f, 0.1f });
}

float3 TraceShadows(float3 color, float3 lightDir, __global uchar * octree, __global uchar * blocks, __read_only image2d_t terrain, float3 hit, int treeDepth, bool inWater, float3 waterEntry, float time)
{
	float4 shadowColor = { 0.0f, 0.0f, 0.0f, 1.0f };
	float4 hitColor = { 0.0f, 0.0f, 0.0f, 0.0f };
	float3 exit = hit + 0.001f * lightDir;
	float3 shadowHit, base, normal;
	uchar tile = 0;
	waterEntry = inWater ? waterEntry : hit;
	while (hitColor.w < 1.0f)
	{
		if (RaySceneIntersection(octree, blocks, terrain, lightDir, exit, treeDepth, inWater, time, &base, &shadowHit, &exit, &tile, &normal, &hitColor))
		{
			if (inWater)
			{
				if (tile == BlockTypeWater || tile == BlockTypeStillWater) { continue; }
				else { shadowColor.w *= (1.0f - min(distance(shadowHit, waterEntry) / 10.0f, 1.0f)); }
			}
			shadowColor.xyz += hitColor.xyz * hitColor.w * shadowColor.w;
			shadowColor.w *= 1.0f - hitColor.w;
			if (!inWater && (tile == BlockTypeWater || tile == BlockTypeStillWater))
			{
				inWater = true;
				waterEntry = shadowHit;
			}
		}
		else { break; }
	}
	return color * shadowColor.w + (shadowColor.xyz * shadowColor.w + 0.375f * color * (1.0f - shadowColor.w)) * (1.0f - shadowColor.w);
}

float3 TraceFog(float3 color, float3 hit, float3 origin, float3 ray)
{
	float d = distance(hit, origin);
	float w = d < 128.0f ? clamp(d / 128.0f, 0.0f, 0.6f) : 0.4f * clamp((d - 128.0f) / 1024.0f, 0.0f, 1.0f) + 0.6f;
	return color * (1.0f - w) + BGColor(ray) * w;
}

float3 TraceReflections(float3 color, float reflectiveness, float3 normal, __global uchar * octree, __global uchar * blocks, __read_only image2d_t terrain, float3 hit, int treeDepth, float3 ray, float3 lightDir, float time)
{
	float4 reflectionColor = { 0.0f, 0.0f, 0.0f, 1.0f };
	float4 hitColor = { 0.0f, 0.0f, 0.0f, 0.0f };
	float3 rRay = normalize(ray - 2.0f * dot(ray, normal) * normal);
	float3 exit = hit + 0.001f * rRay;
	float3 rHit, rNormal, base;
	uchar tile = 0;
	bool inWater = false;
	float3 waterEntry = hit;
	while (hitColor.w < 1.0f)
	{
		if (RaySceneIntersection(octree, blocks, terrain, rRay, exit, treeDepth, inWater, time, &base, &rHit, &exit, &tile, &rNormal, &hitColor))
		{
			if (inWater)
			{
				if (tile == BlockTypeWater || tile == BlockTypeStillWater) { continue; }
				else { reflectionColor.w *= (1.0f - min(distance(rHit, waterEntry) / 10.0f, 1.0f)); }
			}
			hitColor.xyz = TraceLighting(hitColor.xyz, lightDir, rNormal);
			hitColor.xyz = TraceShadows(hitColor.xyz, lightDir, octree, blocks, terrain, rHit, treeDepth, inWater, waterEntry, time);
			reflectionColor.xyz += hitColor.xyz * hitColor.w * reflectionColor.w;
			reflectionColor.w *= 1.0f - hitColor.w;
			if (!inWater && (tile == BlockTypeWater || tile == BlockTypeStillWater))
			{
				inWater = true;
				waterEntry = rHit;
			}
		}
		else
		{
			if (inWater) { reflectionColor.w *= (1.0f - min(distance(rHit, waterEntry) / 10.0f, 1.0f)); }
			reflectionColor.xyz += BGColor(rRay) * reflectionColor.w;
			break;
		}
	}
	reflectionColor.xyz = TraceFog(reflectionColor.xyz, inWater ? waterEntry : rHit, hit, rRay);
	return reflectionColor.xyz * reflectiveness + color * (1.0f - reflectiveness);
}

__kernel void trace(uint treeDepth, __global uchar * octree, __global uchar * blocks, __write_only image2d_t texture, int width, int height, float16 camera, __read_only image2d_t terrain, int isUnderWater, float time)
{
	int x = get_global_id(0);
	int y = get_global_id(1);
	if (x >= width || y >= height) { return; }
	float2 uv = (float2){ 1.0f - 2.0f * (float)x / width, 2.0f * (float)y / height - 1.0f };
	uv.x *= (float)width / height;
	if (isUnderWater) { uv.y += sin(uv.x * (10.0 + sin(time)) + time) / (70.0f + 10.0f * sin(time)); };
	
	float fov = 70.0f;
	float3 origin = MatrixTransformPoint(camera, (float3){ 0.0f, 0.0f, 0.0f });
	float3 ray = normalize(MatrixTransformPoint(camera, (float3){ uv * 0.5f, 0.5f / tanpi(fov / 360.0f) }) - origin);
	
	float3 lightDir = normalize((float3){ 1.0f, 1.0f, 0.5f });
	float4 fragColor = { 0.0f, 0.0f, 0.0f, 1.0f };
	if (isUnderWater)
	{
		float4 water = read_imagef(terrain, TerrainSampler, (float2){ x / (float)width, y / (float)height } / 16.0f + (float2){ 224.0f / 256.0f, 0.0f });
		water.w *= 0.375f;
		fragColor.xyz += water.xyz * water.w * fragColor.w;;
		fragColor.w *= 1.0f - water.w;
	}
	float4 hitColor = { 0.0f, 0.0f, 0.0f, 0.0f };
	float3 exit = origin;
	float3 hit, normal, base;
	uchar tile = 0;
	bool inWater = isUnderWater;
	float3 waterEntry = origin;
	while (hitColor.w < 1.0f)
	{
		if (RaySceneIntersection(octree, blocks, terrain, ray, exit, treeDepth, inWater, time, &base, &hit, &exit, &tile, &normal, &hitColor))
		{
			if (inWater)
			{
				if (tile == BlockTypeWater || tile == BlockTypeStillWater) { continue; }
				else { fragColor.w *= (1.0f - min(distance(hit, waterEntry) / 10.0f, 1.0f)); }
			}
			if ((tile == BlockTypeWater || tile == BlockTypeStillWater) && normal.y > 0.0f) { hit.y += 0.1f; }
			hitColor.xyz = TraceLighting(hitColor.xyz, lightDir, normal);
			hitColor.xyz = TraceShadows(hitColor.xyz, lightDir, octree, blocks, terrain, hit, treeDepth, inWater, waterEntry, time);
			float reflectiveness = GetTileReflectiveness(tile);
			if (reflectiveness > 0.0f) { hitColor.xyz = TraceReflections(hitColor.xyz, reflectiveness, normal, octree, blocks, terrain, hit, treeDepth, ray, lightDir, time); }
			fragColor.xyz += hitColor.xyz * hitColor.w * fragColor.w;
			fragColor.w *= 1.0f - hitColor.w;
			if (!inWater && (tile == BlockTypeWater || tile == BlockTypeStillWater))
			{
				inWater = true;
				waterEntry = hit;
				if (normal.y > 0.0f)
				{
					ray = normalize(ray - 2.0f * dot(ray, normal) * normal) * (float3){ 1.0f, -1.0f, 1.0f };
					exit = hit + distance(hit, exit) * ray;
				}
			}
		}
		else
		{
			if (inWater) { fragColor.w *= (1.0f - min(distance(hit, waterEntry) / 10.0f, 1.0f)); }
			fragColor.xyz += BGColor(ray) * fragColor.w;
			break;
		}
	}
	fragColor.xyz = TraceFog(fragColor.xyz, inWater ? waterEntry : hit, origin, ray);
	if (tile == 255) { fragColor.xyz = (float3){ 0.0f, 0.0f, 0.0f }; }
	write_imagef(texture, (int2){ x, y }, (float4){ fragColor.xyz, 1.0f });
}
