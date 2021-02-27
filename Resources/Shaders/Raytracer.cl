#define BlockTypeGrass 2
#define BlockTypeWater 8
#define BlockTypeStillWater 9
#define BlockTypeLog 17
#define BlockTypeLeaves 18
#define BlockTypeGlass 20
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

float3 BoxNormal(float3 hit, float3 bmin, float3 bmax)
{
	return normalize(round((hit - (bmin + bmax) / 2.0f) / (fabs(bmin - bmax)) * 1.0001f));
}

int GetTextureID(uchar tile, int side)
{
	if (tile == BlockTypeGrass) { return side == 1 ? 0 : (side == 0 ? 2 : 3); }
	if (tile == BlockTypeLog) { return side == 1 ? 21 : (side == 0 ? 21 : 20); }
	if (tile == BlockTypeBookshelf) { return side <= 1 ? 4 : 35; }
	return TextureIDTable[tile] - 1;
}

float GetTileReflectiveness(uchar tile)
{
	if (tile == BlockTypeGlass) { return 0.0f; }
	if (tile == BlockTypeWater || tile == BlockTypeStillWater) { return 0.25f; }
	return 0.0;
}

float3 BGColor(float3 ray)
{
	float t = 1.0f - (1.0f - ray.y) * (1.0f - ray.y);
	return t * (float3){ 0.63f, 0.8f, 1.0f } + (1.0f - t) * (float3){ 1.0f, 1.0f, 1.0f };
}

bool RayTreeIntersection(__global uchar * octree, __global uchar * blocks, __read_only image2d_t terrain, float3 ray, float3 origin, int treeDepth, float3 * hit, float3 * hitExit, uchar * tile, float3 * normal, float4 * color)
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
	float3 base = { 0.0f, 0.0f, 0.0f };
	float mid = size / 2.0f;
	int level = 0;
	int offset = 0;
	int index = 1;
	while (level < treeDepth)
	{
		uchar mask = octree[(index - 1) / 7 + offset];
		uint q = (hit->x > base.x + mid) + 2 * (hit->y > base.y + mid) + 4 * (hit->z > base.z + mid);
		base += mid * convert_float3(((uint3){ q, q, q } >> (uint3){ 0, 1, 2 }) & 1);
		
		if (((mask >> q) & 1) == 0)
		{
			float enter, exit;
			RayBox(ray, *hit, base, base + mid, &enter, &exit);
			//if (exit - enter < 0.004f * distance(*hit, origin)) { *tile = 255; break; }
			*hit += exit * ray + sign(ray) * 0.0001f;
			if (hit->x >= size || hit->y >= size || hit->z >= size || hit->x <= 0.0f || hit->y <= 0.0f || hit->z <= 0.0f) { return false; }
			
			base = (float3){ 0.0f, 0.0f, 0.0f };
			mid = size / 2.0f;
			offset = 0;
			index = 1;
			level = 0;
			continue;
		}
		
		offset = 8 * offset + (int)q;

		if (level == treeDepth - 1)
		{
			int3 v = convert_int3(base);
			if (v.x >= 0 && v.y >= 0 && v.z >= 0 && v.x < sizei && v.y < 64 && v.z < sizei)
			{
				float enter, exit;
				RayBox(ray, origin, base, base + mid, &enter, &exit);
				*hit = origin + ray * enter;
				*hitExit = origin + ray * exit + sign(ray) * 0.0001f;
				*tile = blocks[(v.y * sizei + v.z) * sizei + v.x];
				float2 uv = (float2){ 0.0f, 0.0f };
				float3 norm = *hit - base;
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
				if ((*tile == BlockTypeLeaves) && color->w == 0.0)
				{
					*hit = *hitExit;
					if (hit->x >= size || hit->y >= size || hit->z >= size || hit->x <= 0.0f || hit->y <= 0.0f || hit->z <= 0.0f) { return false; }
					base = (float3){ 0.0f, 0.0f, 0.0f };
					mid = size / 2.0f;
					offset = 0;
					index = 1;
					level = 0;
					continue;
				}
				if (id == -1) { *color = (float4){ 1.0f, 0.0f, 1.0f, 1.0f }; }
				*normal = BoxNormal(*hit, base, base + mid);
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

float3 TraceLighting(float3 color, float3 lightDir, float3 normal)
{
	return color * (max(dot(lightDir, normal), -1.0f) * 0.25f + 0.75f);
}

float3 TraceShadows(float3 color, float3 lightDir, __global uchar * octree, __global uchar * blocks, __read_only image2d_t terrain, float3 hit, int treeDepth)
{
	float4 shadowColor = { 0.0f, 0.0f, 0.0f, 1.0f };
	float4 hitColor = { 0.0f, 0.0f, 0.0f, 0.0f };
	float3 exit = hit + 0.001f * lightDir;
	float3 shadowHit, normal;
	uchar tile = 0;
	bool inWater = false;
	float3 waterEntry = hit;
	while (hitColor.w < 1.0)
	{
		if (RayTreeIntersection(octree, blocks, terrain, lightDir, exit, treeDepth, &shadowHit, &exit, &tile, &normal, &hitColor))
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
	return color * shadowColor.w + (shadowColor.xyz * shadowColor.w + 0.5f * color * (1.0f - shadowColor.w)) * (1.0f - shadowColor.w);
}

float3 TraceFog(float3 color, float3 hit, float3 origin, float3 ray)
{
	float w = clamp(distance(hit, origin) / 128.0f, 0.0f, 0.6f);
	return color * (1.0f - w) + BGColor(ray) * w;
}

float3 TraceReflections(float3 color, float reflectiveness, float3 normal, __global uchar * octree, __global uchar * blocks, __read_only image2d_t terrain, float3 hit, int treeDepth, float3 ray, float3 lightDir)
{
	float4 reflectionColor = { 0.0f, 0.0f, 0.0f, 1.0f };
	float4 hitColor = { 0.0f, 0.0f, 0.0f, 0.0f };
	float3 rRay = normalize(ray - 2.0f * dot(ray, normal) * normal);
	float3 exit = hit + 0.001f * rRay;
	float3 rHit, rNormal;
	uchar tile = 0;
	bool inWater = false;
	float3 waterEntry = hit;
	while (hitColor.w < 1.0f)
	{
		if (RayTreeIntersection(octree, blocks, terrain, rRay, exit, treeDepth, &rHit, &exit, &tile, &rNormal, &hitColor))
		{
			if (inWater)
			{
				if (tile == BlockTypeWater || tile == BlockTypeStillWater) { continue; }
				else { reflectionColor.w *= (1.0f - min(distance(rHit, waterEntry) / 10.0f, 1.0f)); }
			}
			hitColor.xyz = TraceLighting(hitColor.xyz, lightDir, rNormal);
			hitColor.xyz = TraceShadows(hitColor.xyz, lightDir, octree, blocks, terrain, rHit, treeDepth);
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
	reflectionColor.xyz = TraceFog(reflectionColor.xyz, rHit, hit, rRay);
	return reflectionColor.xyz * reflectiveness + color * (1.0f - reflectiveness);
}

__kernel void trace(uint treeDepth, __global uchar * octree, __global uchar * blocks, __write_only image2d_t texture, int width, int height, float16 camera, __read_only image2d_t terrain)
{
	int x = get_global_id(0);
	int y = get_global_id(1);
	if (x >= width || y >= height) { return; }
	float2 uv = (float2){ 1.0f - 2.0f * (float)x / width, 2.0f * (float)y / height - 1.0f };
	uv.x *= (float)width / height;
	
	float fov = 70.0f;
	float3 origin = MatrixTransformPoint(camera, (float3){ 0.0f, 0.0f, 0.0f });
	float3 ray = normalize(MatrixTransformPoint(camera, (float3){ uv * 0.5f, 0.5f / tanpi(fov / 360.0f) }) - origin);
	
	float4 finalColor = { BGColor(ray), 1.0f };
	float3 lightDir = normalize((float3){ 1.0f, 1.0f, 0.5f });
	
	float4 fragColor = { 0.0f, 0.0f, 0.0f, 1.0f };
	float4 hitColor = { 0.0f, 0.0f, 0.0f, 0.0f };
	float3 exit = origin;
	float3 hit, normal;
	uchar tile = 0;
	bool inWater = false;
	float3 waterEntry = origin;
	while (hitColor.w < 1.0f)
	{
		if (RayTreeIntersection(octree, blocks, terrain, ray, exit, treeDepth, &hit, &exit, &tile, &normal, &hitColor))
		{
			if (inWater)
			{
				if (tile == BlockTypeWater || tile == BlockTypeStillWater) { continue; }
				else { fragColor.w *= (1.0f - min(distance(hit, waterEntry) / 10.0f, 1.0f)); }
			}
			hitColor.xyz = TraceLighting(hitColor.xyz, lightDir, normal);
			hitColor.xyz = TraceShadows(hitColor.xyz, lightDir, octree, blocks, terrain, hit, treeDepth);
			float reflectiveness = GetTileReflectiveness(tile);
			if (reflectiveness > 0.0f) { hitColor.xyz = TraceReflections(hitColor.xyz, reflectiveness, normal, octree, blocks, terrain, hit, treeDepth, ray, lightDir); }
			fragColor.xyz += hitColor.xyz * hitColor.w * fragColor.w;
			fragColor.w *= 1.0f - hitColor.w;
			if (!inWater && (tile == BlockTypeWater || tile == BlockTypeStillWater))
			{
				inWater = true;
				waterEntry = hit;
			}
		}
		else
		{
			if (inWater) { fragColor.w *= (1.0f - min(distance(hit, waterEntry) / 10.0f, 1.0f)); }
			fragColor.xyz += BGColor(ray) * fragColor.w;
			break;
		}
	}
	fragColor.xyz = TraceFog(fragColor.xyz, hit, origin, ray);
	finalColor.xyz = fragColor.xyz;
	if (tile == 255) { finalColor.xyz = (float3){ 0.0f, 0.0f, 0.0f }; }
	write_imagef(texture, (int2){ x, y }, finalColor);
}
