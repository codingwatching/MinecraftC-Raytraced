#pragma once
#include "Utilities/String.h"
#include "Level/Tile/Block.h"

extern list(Block) SessionDataAllowedBlocks;
void SessionDataInitialize(void);
void SessionDataDeinitialize(void);
