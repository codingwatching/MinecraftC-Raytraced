#pragma once
#include "GUIScreen.h"
#include "../GameSettings.h"

typedef GUIScreen OptionsScreen;

typedef struct OptionsScreenData
{
	GUIScreen Parent;
	char * Title;
	GameSettings Settings;
} * OptionsScreenData;

OptionsScreen OptionsScreenCreate(GUIScreen parent, GameSettings settings);
void OptionsScreenOnOpen(OptionsScreen screen);
void OptionsScreenOnButtonClicked(OptionsScreen screen, Button button);
void OptionsScreenRender(OptionsScreen screen, int2 mousePos);
void OptionsScreenDestroy(OptionsScreen screen);
