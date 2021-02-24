#include "Entity.h"
#include "Level/Level.h"
#include "Player/Player.h"

Entity EntityCreate(Level level)
{
	Entity entity = MemoryAllocate(sizeof(struct Entity));
	*entity = (struct Entity)
	{
		.OnGround = false,
		.HorizontalCollision = false,
		.Collision = false,
		.Slide = true,
		.Removed = false,
		.HeightOffset = 0.0,
		.AABBWidth = 0.6,
		.AABBHeight = 1.8,
		.OldWalkDistance = 0.0,
		.WalkDistance = 0.0,
		.MakeStepSound = true,
		.FallDistance = 0.0,
		.NextStep = 1,
		.TextureID = 0,
		.YSlideOffset = 0.0,
		.FootSize = 0.0,
		.NoPhysics = false,
		.PushThrough = 0.0,
		.Hovered = false,
		.Level = level,
	};
	EntitySetPosition(entity, zero3f);
	return entity;
}

void EntityResetPosition(Entity entity)
{
	if (entity->Type == EntityTypePlayer) { return PlayerResetPosition(entity); }
	if (entity->Level != NULL)
	{
		float2 spawn = { entity->Level->Spawn.x + 0.5, entity->Level->Spawn.y };
		
		for (float z = entity->Level->Spawn.z + 0.5; z > 0.0; z++)
		{
			EntitySetPosition(entity, (float3){ spawn.x, spawn.y, z });
			list(AABB) cubes = LevelGetCubes(entity->Level, entity->AABB);
			if (ListCount(cubes) == 0)
			{
				ListDestroy(cubes);
				break;
			}
			ListDestroy(cubes);
		}
		
		entity->Delta = zero3f;
		entity->Rotation.y = entity->Level->SpawnRotation;
		entity->Rotation.x = 0.0;
	}
}

void EntityRemove(Entity entity)
{
	if (entity->Type == EntityTypePlayer) { return PlayerRemove(entity); }
	entity->Removed = true;
}

void EntitySetSize(Entity entity, float w, float h)
{
	entity->AABBWidth = w;
	entity->AABBHeight = h;
}

void EntitySetPosition(Entity entity, float3 pos)
{
	entity->Position = pos;
	float w = entity->AABBWidth / 2.0;
	float h = entity->AABBHeight / 2.0;
	entity->AABB = (AABB){ .V0 = { pos.x - w, pos.y - h, pos.z - w }, .V1 = { pos.x + w, pos.y + h, pos.z + w } };
}

void EntityTurn(Entity entity, float2 angle)
{
	float2 old = entity->Rotation;
	entity->Rotation += (float2){ -angle.x, angle.y } * 0.15;
	entity->Rotation.x = entity->Rotation.x < -90.0 ? -90.0 : (entity->Rotation.x > 90.0 ? 90.0 : entity->Rotation.x);
	entity->OldRotation += entity->Rotation - old;
}

void EntityInterpolateTurn(Entity entity, float2 angle)
{
	entity->Rotation += (float2){ -angle.x, angle.y } * 0.15;
	entity->Rotation.x = entity->Rotation.x < -90.0 ? -90.0 : (entity->Rotation.x > 90.0 ? 90.0 : entity->Rotation.x);
}

void EntityTick(Entity entity)
{
	if (entity->Type == EntityTypeParticle) { return ParticleTick(entity); }
	
	entity->OldWalkDistance = entity->WalkDistance;
	entity->OldPosition = entity->Position;
	entity->OldRotation = entity->Rotation;
	
	if (entity->Type == EntityTypePlayer) { return PlayerTick(entity); }
}

bool EntityIsFree(Entity entity, float3 a)
{
	AABB aabb = AABBMove(entity->AABB, a);
	list(AABB) cubes = LevelGetCubes(entity->Level, aabb);
	bool free = ListCount(cubes) > 0 ? false : !LevelContainsAnyLiquid(entity->Level, aabb);
	ListDestroy(cubes);
	return free;
}

bool EntityIsFreeScaled(Entity entity, float3 a, float s)
{
	AABB aabb = AABBMove(AABBGrow(entity->AABB, one3f * s), a);
	list(AABB) cubes = LevelGetCubes(entity->Level, aabb);
	bool free = ListCount(cubes) > 0 ? false : !LevelContainsAnyLiquid(entity->Level, aabb);
	ListDestroy(cubes);
	return free;
}

void EntityMove(Entity entity, float3 a)
{
	if (entity->NoPhysics)
	{
		entity->AABB = AABBMove(entity->AABB, a);
		entity->Position.xz = (entity->AABB.V0.xz + entity->AABB.V1.xz) / 2.0;
		entity->Position.y = entity->AABB.V0.y + entity->HeightOffset - entity->YSlideOffset;
	}
	else
	{
		float2 xz = entity->Position.xz;
		float3 old = a;
		AABB oldAABB = entity->AABB;
		list(AABB) cubes = LevelGetCubes(entity->Level, AABBExpand(entity->AABB, a));
		
		for (int i = 0; i < ListCount(cubes); i++)
		{
			AABB aabb = { .V0 = { ((float *)&cubes[i].V0)[0], ((float *)&cubes[i].V0)[1], ((float *)&cubes[i].V0)[2] }, .V1 = { ((float *)&cubes[i].V1)[0], ((float *)&cubes[i].V1)[1], ((float *)&cubes[i].V1)[2] } };
			a.y = AABBClipYCollide(aabb, entity->AABB, a.y);
		}
		entity->AABB = AABBMove(entity->AABB, up3f * a.y);
		if (!entity->Slide && old.y != a.y) { a = zero3f; }
		for (int i = 0; i < ListCount(cubes); i++)
		{
			AABB aabb = { .V0 = { ((float *)&cubes[i].V0)[0], ((float *)&cubes[i].V0)[1], ((float *)&cubes[i].V0)[2] }, .V1 = { ((float *)&cubes[i].V1)[0], ((float *)&cubes[i].V1)[1], ((float *)&cubes[i].V1)[2] } };
			a.x = AABBClipXCollide(aabb, entity->AABB, a.x);
		}
		entity->AABB = AABBMove(entity->AABB, right3f * a.x);
		if (!entity->Slide && old.x != a.x) { a = zero3f; }
		for (int i = 0; i < ListCount(cubes); i++)
		{
			AABB aabb = { .V0 = { ((float *)&cubes[i].V0)[0], ((float *)&cubes[i].V0)[1], ((float *)&cubes[i].V0)[2] }, .V1 = { ((float *)&cubes[i].V1)[0], ((float *)&cubes[i].V1)[1], ((float *)&cubes[i].V1)[2] } };
			a.z = AABBClipZCollide(aabb, entity->AABB, a.z);
		}
		entity->AABB = AABBMove(entity->AABB, forward3f * a.z);
		if (!entity->Slide && old.z != a.z) { a = zero3f; }
		bool onGround = entity->OnGround || (old.y != a.y && old.y < 0.0);
		ListDestroy(cubes);
		
		if (entity->FootSize > 0.0 && onGround && entity->YSlideOffset < 0.05 && (old.x != a.x || old.z != a.z))
		{
			float3 b = a;
			a = (float3){ old.x, entity->FootSize, old.z };
			AABB tempAABB = entity->AABB;
			entity->AABB = oldAABB;
			list(AABB) cubes = LevelGetCubes(entity->Level, AABBExpand(entity->AABB, (float3){ old.x, a.y, old.z }));
			
			for (int i = 0; i < ListCount(cubes); i++)
			{
				AABB aabb = { .V0 = { ((float *)&cubes[i].V0)[0], ((float *)&cubes[i].V0)[1], ((float *)&cubes[i].V0)[2] }, .V1 = { ((float *)&cubes[i].V1)[0], ((float *)&cubes[i].V1)[1], ((float *)&cubes[i].V1)[2] } };
				a.y = AABBClipYCollide(aabb, entity->AABB, a.y);
			}
			entity->AABB = AABBMove(entity->AABB, up3f * a.y);
			if (!entity->Slide && old.y != a.y) { a = zero3f; }
			for (int i = 0; i < ListCount(cubes); i++)
			{
				AABB aabb = { .V0 = { ((float *)&cubes[i].V0)[0], ((float *)&cubes[i].V0)[1], ((float *)&cubes[i].V0)[2] }, .V1 = { ((float *)&cubes[i].V1)[0], ((float *)&cubes[i].V1)[1], ((float *)&cubes[i].V1)[2] } };
				a.x = AABBClipXCollide(aabb, entity->AABB, a.x);
			}
			entity->AABB = AABBMove(entity->AABB, right3f * a.x);
			if (!entity->Slide && old.x != a.x) { a = zero3f; }
			for (int i = 0; i < ListCount(cubes); i++)
			{
				AABB aabb = { .V0 = { ((float *)&cubes[i].V0)[0], ((float *)&cubes[i].V0)[1], ((float *)&cubes[i].V0)[2] }, .V1 = { ((float *)&cubes[i].V1)[0], ((float *)&cubes[i].V1)[1], ((float *)&cubes[i].V1)[2] } };
				a.z = AABBClipZCollide(aabb, entity->AABB, a.z);
			}
			entity->AABB = AABBMove(entity->AABB, forward3f * a.z);
			if (!entity->Slide && old.z != a.z) { a = zero3f; }
			ListDestroy(cubes);
			
			if (b.x * b.x + b.z * b.z >= a.x * a.x + a.z * a.z)
			{
				a = b;
				entity->AABB = tempAABB;
			}
			else { entity->YSlideOffset += 0.5; }
		}
		
		entity->HorizontalCollision = old.x != a.x || old.z != a.z;
		entity->OnGround = old.y != a.y && old.y < 0.0;
		entity->Collision = entity->HorizontalCollision || old.y != a.y;
		if (entity->OnGround)
		{
			if (entity->FallDistance > 0.0) { entity->FallDistance = 0.0; }
		}
		else if (a.y < 0.0) { entity->FallDistance -= a.y; }
		
		if (old.x != a.x) { entity->Delta.x = 0.0; }
		if (old.y != a.y) { entity->Delta.y = 0.0; }
		if (old.z != a.z) { entity->Delta.z = 0.0; }
		
		entity->Position.xz = (entity->AABB.V0.xz + entity->AABB.V1.xz) / 2.0;
		entity->Position.y = entity->AABB.V0.y + entity->HeightOffset - entity->YSlideOffset;
		entity->WalkDistance += distance2f(entity->Position.xz, xz) * 0.6;
		if (entity->MakeStepSound)
		{
			BlockType blockType = LevelGetTile(entity->Level, entity->Position.x, entity->Position.y - entity->HeightOffset - 0.2, entity->Position.z);
			if (entity->WalkDistance > entity->NextStep && blockType > 0)
			{
				entity->NextStep++;
				TileSound sound = Blocks.Table[blockType]->Sound;
				if (sound.Type != TileSoundTypeNone)
				{
					EntityPlaySound(entity, "step.", TileSoundGetVolume(sound) * 0.75, TileSoundGetPitch(sound));
				}
			}
		}
		entity->YSlideOffset *= 0.4;
	}
}

bool EntityIsInWater(Entity entity)
{
	return LevelContainsLiquid(entity->Level, AABBGrow(entity->AABB, up3f * -0.4), LiquidTypeWater);
}

bool EntityIsUnderWater(Entity entity)
{
	BlockType blockType = LevelGetTile(entity->Level, entity->Position.x, entity->Position.y, entity->Position.z);
	return blockType != 0 ? BlockGetLiquidType(Blocks.Table[blockType]) == LiquidTypeWater : false;
}

bool EntityIsInLava(Entity entity)
{
	return LevelContainsLiquid(entity->Level, AABBGrow(entity->AABB, one3f * -0.4), LiquidTypeLava);
}

void EntityMoveRelative(Entity entity, float2 xz, float speed)
{
	float len = length2f(xz);
	if (len >= 0.01)
	{
		if (len < 1.0) { len = 1.0; }
		len = speed / len;
		xz *= len;
		float s = sin(entity->Rotation.y * rad);
		float c = cos(entity->Rotation.y * rad);
		entity->Delta.x += xz.x * c - xz.y * s;
		entity->Delta.z += xz.y * c + xz.x * s;
	}
}

bool EntityIsLit(Entity entity)
{
	return LevelIsLit(entity->Level, entity->Position.x, entity->Position.y, entity->Position.z);
}

float EntityGetBrightness(Entity entity, float t)
{
	return LevelGetBrightness(entity->Level, entity->Position.x, entity->Position.y, entity->Position.z);
}

void EntitySetLevel(Entity entity, Level level)
{
	entity->Level = level;
}

void EntityPlaySound(Entity entity, const char * name, float volume, float pitch)
{
	LevelPlaySound(entity->Level, name, entity, volume, pitch);
}

void EntityMoveTo(Entity entity, float3 pos, float2 rot)
{
	entity->OldPosition = entity->Position;
	entity->Position = pos;
	entity->Rotation = rot;
	EntitySetPosition(entity, pos);
}

float EntityDistanceTo(Entity entityA, Entity entityB)
{
	return distance3f(entityA->Position, entityB->Position);
}

float EntityDistanceToPoint(Entity entity, float3 point)
{
	return distance3f(entity->Position, point);
}

float EntitySquaredDistanceTo(Entity entityA, Entity entityB)
{
	return sqdistance3f(entityA->Position, entityB->Position);
}

void EntityPushTowards(Entity entity, float3 point)
{
	entity->Delta += point;
}

bool EntityIntersects(Entity entity, float3 v0, float3 v1)
{
	return AABBIntersects(entity->AABB, (AABB){ v0, v1 });
}

bool EntityIsPickable(Entity entity)
{
	if (entity->Type == EntityTypePlayer) { return PlayerIsPickable(entity); }
	return false;
}

bool EntityShouldRender(Entity entity, float3 v)
{
	return EntityShouldRenderAtSquaredDistance(entity, sqdistance3f(entity->Position, v));
}

bool EntityShouldRenderAtSquaredDistance(Entity entity, float v)
{
	return v < pow(AABBGetSize(entity->AABB) * 64.0, 2.0);
}

int EntityGetTexture(Entity entity)
{
	return entity->TextureID;
}

void EntityDestroy(Entity entity)
{
	if (entity->Type == EntityTypePlayer) { PlayerDestroy(entity); }
	if (entity->Type == EntityTypeParticle) { ParticleDestroy(entity); }
	MemoryFree(entity);
}
