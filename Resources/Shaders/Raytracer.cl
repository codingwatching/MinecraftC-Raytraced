
__kernel void trace(uint treeDepth, __global uchar * octree, __global uchar * blocks, int width, int height, __write_only image2d_t texture)
{
	int x = get_global_id(0);
	int y = get_global_id(1);
	float2 uv = { (float)x / width, (float)y / height };
	write_imagef(texture, (int2){ x, y }, (float4){ uv, 1.0, 1.0 });
}
