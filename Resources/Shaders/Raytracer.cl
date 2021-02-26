#define BlockTypeGrass 2
#define BlockTypeWater 8
#define BlockTypeStillWater 9
#define BlockTypeLog 17
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

float3 BGColor(float3 ray)
{
	float t = 1.0f - (1.0f - ray.y) * (1.0f - ray.y);
	return t * (float3){ 0.63f, 0.8f, 1.0f } + (1.0f - t) * (float3){ 1.0f, 1.0f, 1.0f };
}

bool RayTreeIntersection(__global uchar * octree, __global uchar * blocks, __read_only image2d_t terrain, float3 ray, float3 origin, int treeDepth, float depth, float3 * hit, uchar * tile, float3 * normal, float4 * color)
{
	*tile = 0;
	float size = pow(2.0, (float)treeDepth);
	int sizei = 1;
	for (int i = 0; i < treeDepth; i++) { sizei *= 2; }
	float dist;
	if (!RayBoxIntersection(ray, origin, (float3){ 0.0f, 0.0f, 0.0f }, (float3){ 1.0f, 1.0f, 1.0f } * size, &dist) || dist > depth)
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
			*hit += exit * ray + sign(ray) * size * 0.000001f;
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
				*hit -= 0.000001f * sign(ray) * size;
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
				if (id == -1) { *color = (float4){ 1.0, 0.0, 1.0, 1.0 }; }
				if (color->w == 0.0f)
				{
					float enter, exit;
					RayBox(ray, *hit, base, base + mid, &enter, &exit);
					*hit += exit * ray + sign(ray) * size * 0.000001f;
					if (hit->x >= size || hit->y >= size || hit->z >= size || hit->x <= 0.0f || hit->y <= 0.0f || hit->z <= 0.0f) { return false; }
					base = (float3){ 0.0f, 0.0f, 0.0f };
					mid = size / 2.0f;
					offset = 0;
					index = 1;
					level = 0;
					continue;
				}
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
	float depth = 1.0f / 0.0f;
	
	float3 hit, normal;
	float4 color;
	uchar tile = 0;
	if (RayTreeIntersection(octree, blocks, terrain, ray, origin, treeDepth, depth, &hit, &tile, &normal, &color) && distance(hit, origin) < depth)
	{
		depth = distance(hit, origin);
		float3 lightDir = normalize((float3){ 1.0f, 1.0f, 0.5f });
		float diff = max(dot(lightDir, normal), -1.0f);
		finalColor.xyz = color.xyz * (diff * 0.25f + 0.75f);
		
		float3 reflection = ray;
		float3 rHit = hit;
		float reflectiveness = 0.25;
		for (int i = 0; i < 5; i++)
		{
			if (tile == BlockTypeWater || tile == BlockTypeStillWater)
			{
				reflection = normalize(reflection - 2.0f * dot(reflection, normal) * normal);
				if (RayTreeIntersection(octree, blocks, terrain, reflection, rHit + 0.001f * reflection, treeDepth, depth, &rHit, &tile, &normal, &color))
				{
					finalColor.xyz = (1.0 - reflectiveness) * finalColor.xyz + reflectiveness * color.xyz;
				}
				else
				{
					finalColor.xyz = (1.0 - reflectiveness) * finalColor.xyz + reflectiveness * BGColor(reflection);
				}
				reflectiveness /= 2.0;
			}
			else { break; }
		}
		
		float3 shadowHit;
		if (RayTreeIntersection(octree, blocks, terrain, lightDir, hit + 0.001f * lightDir, treeDepth, 1.0f / 0.0f, &shadowHit, &tile, &normal, &color))
		{
			finalColor.xyz *= 0.5f;
		}
		
		float w = clamp(depth / 128.0f, 0.0f, 0.6f);
		finalColor.xyz = finalColor.xyz * (1.0f - w) + BGColor(ray) * w;
	}
	if (tile == 255) { finalColor.xyz = (float3){ 0.0f, 0.0f, 0.0f }; }
	write_imagef(texture, (int2){ x, y }, finalColor);
}
