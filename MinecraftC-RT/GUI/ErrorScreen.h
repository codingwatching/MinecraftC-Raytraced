#pragma once
#include "GUIScreen.h"

typedef GUIScreen ErrorScreen;

typedef struct ErrorScreenData
{
	char * Title;
	char * Text;
} * ErrorScreenData;

ErrorScreen ErrorScreenCreate(char * title, char * text);
void ErrorScreenOnOpen(ErrorScreen screen);
void ErrorScreenRender(ErrorScreen screen, int2 mousePos);
void ErrorScreenOnKeyPressed(ErrorScreen screen, char eventChar, int eventKey);
void ErrorScreenDestroy(ErrorScreen screen);
