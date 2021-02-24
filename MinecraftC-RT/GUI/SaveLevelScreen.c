#include "SaveLevelScreen.h"
#include "LevelNameScreen.h"
#include "Screen.h"
#include "../Minecraft.h"

SaveLevelScreen SaveLevelScreenCreate(GUIScreen parent)
{
	GUIScreen screen = LoadLevelScreenCreate(parent);
	screen->Type = GUIScreenTypeSaveLevel;
	LoadLevelScreenData this = screen->TypeData;
	this->Title = "Save level";
	this->Saving = true;
	this->Parent = parent;
	return screen;
}

void SaveLevelScreenSetLevels(SaveLevelScreen screen, char * strings[5])
{
	for (int i = 0; i < 5; i++)
	{
		screen->Buttons[i]->Text = StringSet(screen->Buttons[i]->Text, strings[i]);
		screen->Buttons[i]->Visible = true;
	}
}

void SaveLevelScreenOnOpen(SaveLevelScreen screen)
{
	screen->Buttons[5]->Text = StringSet(screen->Buttons[5]->Text, "Save file...");
}

void SaveLevelScreenOpenLevel(SaveLevelScreen screen, int level)
{
	MinecraftSetCurrentScreen(screen->Minecraft, LevelNameScreenCreate(screen, screen->Buttons[level]->Text, level));
}

void SaveLevelScreenOpenLevelFromFile(SaveLevelScreen screen, char * file)
{
	LoadLevelScreenData this = screen->TypeData;
	LevelIOSave(screen->Minecraft->LevelIO, screen->Minecraft->Level, SDL_RWFromFile(file, "wb"));
	MinecraftSetCurrentScreen(screen->Minecraft, this->Parent);
}

void SaveLevelScreenRender(SaveLevelScreen screen, int2 mousePos)
{
}
