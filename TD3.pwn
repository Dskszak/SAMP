// Start Of File

/*
Editor de TextDraw do Zamaroht Versao 1.0RC2.
Projetado para SA-MP 0.3.

Autor: Zamaroht (Nicolas Laurito)

Inicio do desenvolvimento: 25 de dezembro de 2009, 22:16 (GMT-3)
Termino do desenvolvimento: 01 de janeiro de 2010, 23:31 (GMT-3)

Aviso legal:
Voce pode redistribuir este arquivo como desejar, mas SEMPRE mantendo o nome do
autor e um link de volta para http://forum.sa-mp.com/index.php?topic=143025.0
anexado ao meio de distribuicao.
Por exemplo, o link com o nome do autor em um topico de forum publico, ou um
arquivo README separado em um arquivo .zip, etc.
Se voce modificar este arquivo, os mesmos termos se aplicam. Voce deve incluir o autor
original (Zamaroht) e o link de volta para a pagina mencionada.

Registro de alteracoes:
	25/10/2012
	- Funcao PlayerTextDraw adicionada por adri1
	
	26/10/2012
	- Funcao SetSelectable adicionada por adri1
	
	11/01/2013
	- Funcoes de TextDraw 2D adicionadas por adri1
	
	01/02/2020
	- Funcao para definir Global ou Player e modo de exportacao Misto
	  adicionadas por ForT.
*/
#pragma disablerecursion
#include <a_samp>
#include <zcmd>
#include <Dini>

// =============================================================================
// Declaracoes Internas.
// =============================================================================

#define MAX_TEXTDRAWS       90			// Max textdraws shown on client screen is 92. Using 90 to be on the safe side.
#define MSG_COLOR           0xFAF0CEFF	// Color to be shown in the messages.
#define PREVIEW_CHARS       35			// Amount of characters that show on the textdraw's preview.


// Used with P_Aux
#define DELETING 0
#define LOADING 1

// Used with P_KeyEdition
#define EDIT_NONE       0
#define EDIT_POSITION   1
#define EDIT_SIZE       2
#define EDIT_BOX        3
#define EDIT_BOX_INPUT  4  // New mode for input-based box editing

// Used with P_ColorEdition
#define COLOR_TEXT      0
#define COLOR_OUTLINE   1
#define COLOR_BOX       2

enum enum_tData // Textdraw data.
{
	bool:T_Created,			// Wheter the textdraw ID is created or not.
	Text:T_Handler,         // Where the TD id is saved itself.
	T_Text[1536],           // The textdraw's string.
	Float:T_X,
	Float:T_Y,
	T_Alignment,
	T_BackColor,
	T_BoxColor,
	T_Color,
	T_Font,
	Float:T_XSize,
	Float:T_YSize,
	T_Outline,
	T_Proportional,
	T_Shadow,
	Float:T_TextSizeX,
	Float:T_TextSizeY,
	T_UseBox,
	T_Selectable,
	T_PreviewModel,
	T_Mode,
	Float:PMRotX,
	Float:PMRotY,
	Float:PMRotZ,
	Float:PMZoom
};

	enum enum_pData // Player data.
	{
		bool:P_Editing,         // Wheter the player is editing or not at the moment (allow /menu).
		P_DialogPage,           // Page of the textdraw selection dialog they are at.
		P_CurrentTextdraw,      // Textdraw ID being currently edited.
		P_CurrentMenu,          // Just used at the start, to know if the player is LOADING or DELETING.
		P_KeyEdition,           // Used to know which editions is being performed with keyboard. Check defines.
		P_Aux,      	    // Auxiliar variable, used as a temporal variable in various cases.
		P_ColorEdition,         // Used to know WHAT the player is changing the color of. Check defines.
		P_Color[4],             // Holds RGBA when using color combinator.
		P_ExpCommand[128],      // Holds temporaly the command which will be used for a command fscript export.
		P_Aux2,                 // Just used in special export cases.
		bool:P_ClickTestMode,   // Whether player is in click-test mode to capture clicks.
		P_ClickTestInfo[64],    // Buffer for last click info.
		// Color UI state
		P_ColorPageStart,       // Pagination start index for premade colors list
		P_ColorFilter[32],      // Current filter substring for colors
		P_ColorSortMode,        // 0 = default, 1 = alphabetical (PT)
		P_ColorGroup,           // 0 = all, >0 specific group
		P_RecentColors[10],     // Circular buffer of recent color indices
		P_RecentCount,          // Count of recent items
		P_PendingColorIndex,    // Selected color index awaiting alpha selection
		P_ColorAlpha,           // Last selected alpha (0-255)
		// Favorites
		P_Favorites[20],        // Favorite color indices (HTML_COLORS indexes)
		P_FavoriteCount,        // Count of favorite items
		bool:P_ClickAreaOverlayEnabled,	// Click-area overlay toggle
		PlayerText:P_ClickAreaOverlay,	// Handle for player's overlay TD
		PlayerText:P_ClickGuideW,	// Handle for width guide TD
		PlayerText:P_ClickGuideH,	// Handle for height guide TD
		// Alignment clickable guide state
		bool:P_AlignGuideVisible,
		PlayerText:P_AlignGuideL,
		PlayerText:P_AlignGuideC,
		PlayerText:P_AlignGuideR,
		// Selection highlight color used by SelectTextDraw
		P_SelectColor
	};

new tData[MAX_TEXTDRAWS][enum_tData],
	pData[MAX_PLAYERS][enum_pData];
	
new CurrentProject[128];  // String containing the location of the current opened project file.

#define INVALID_PLAYER_TEXT_DRAW PlayerText:65535
#define CLICK_OVERLAY_COLOR 0xAA00FF00
#define CLICK_GUIDE_W_COLOR 0xAAFF0000
#define CLICK_GUIDE_H_COLOR 0xAA0000FF
#define ALIGN_GUIDE_L_COLOR 0xAAAA4444
#define ALIGN_GUIDE_C_COLOR 0xAA44AA44
#define ALIGN_GUIDE_R_COLOR 0xAA4444AA

stock RebuildClickAreaOverlay(playerid)
{
	new current = pData[playerid][P_CurrentTextdraw];
	// Destroy any existing overlay first
	if(pData[playerid][P_ClickAreaOverlay] != INVALID_PLAYER_TEXT_DRAW)
	{
		PlayerTextDrawDestroy(playerid, pData[playerid][P_ClickAreaOverlay]);
		pData[playerid][P_ClickAreaOverlay] = INVALID_PLAYER_TEXT_DRAW;
	}
	if(pData[playerid][P_ClickGuideW] != INVALID_PLAYER_TEXT_DRAW)
	{
		PlayerTextDrawDestroy(playerid, pData[playerid][P_ClickGuideW]);
		pData[playerid][P_ClickGuideW] = INVALID_PLAYER_TEXT_DRAW;
	}
	if(pData[playerid][P_ClickGuideH] != INVALID_PLAYER_TEXT_DRAW)
	{
		PlayerTextDrawDestroy(playerid, pData[playerid][P_ClickGuideH]);
		pData[playerid][P_ClickGuideH] = INVALID_PLAYER_TEXT_DRAW;
	}
	if(!pData[playerid][P_ClickAreaOverlayEnabled]) return 1;
	if(current < 0 || current >= MAX_TEXTDRAWS || !tData[current][T_Created]) return 1;
	
	new Float:x = tData[current][T_X];
	new Float:y = tData[current][T_Y];
	new Float:w = tData[current][T_TextSizeX];
	new Float:h = tData[current][T_TextSizeY];
	
	pData[playerid][P_ClickAreaOverlay] = CreatePlayerTextDraw(playerid, x, y, " ");
	PlayerTextDrawFont(playerid, pData[playerid][P_ClickAreaOverlay], 1);
	PlayerTextDrawLetterSize(playerid, pData[playerid][P_ClickAreaOverlay], 0.0, 0.0);
	PlayerTextDrawUseBox(playerid, pData[playerid][P_ClickAreaOverlay], 1);
	PlayerTextDrawBoxColor(playerid, pData[playerid][P_ClickAreaOverlay], CLICK_OVERLAY_COLOR);
	PlayerTextDrawTextSize(playerid, pData[playerid][P_ClickAreaOverlay], w, h);
	PlayerTextDrawBackgroundColor(playerid, pData[playerid][P_ClickAreaOverlay], 0);
	PlayerTextDrawSetOutline(playerid, pData[playerid][P_ClickAreaOverlay], 1);
	PlayerTextDrawSetProportional(playerid, pData[playerid][P_ClickAreaOverlay], 1);
	PlayerTextDrawSetSelectable(playerid, pData[playerid][P_ClickAreaOverlay], 0);
	PlayerTextDrawShow(playerid, pData[playerid][P_ClickAreaOverlay]);
	
	// Create width guide (single red overlay spanning full height)
	pData[playerid][P_ClickGuideW] = CreatePlayerTextDraw(playerid, x, y, " ");
	PlayerTextDrawFont(playerid, pData[playerid][P_ClickGuideW], 1);
	PlayerTextDrawLetterSize(playerid, pData[playerid][P_ClickGuideW], 0.0, 0.0);
	PlayerTextDrawUseBox(playerid, pData[playerid][P_ClickGuideW], 1);
	PlayerTextDrawBoxColor(playerid, pData[playerid][P_ClickGuideW], CLICK_GUIDE_W_COLOR);
	PlayerTextDrawTextSize(playerid, pData[playerid][P_ClickGuideW], w, h);
	PlayerTextDrawBackgroundColor(playerid, pData[playerid][P_ClickGuideW], 0);
	PlayerTextDrawSetOutline(playerid, pData[playerid][P_ClickGuideW], 0);
	PlayerTextDrawSetProportional(playerid, pData[playerid][P_ClickGuideW], 1);
	PlayerTextDrawSetSelectable(playerid, pData[playerid][P_ClickGuideW], 0);
	PlayerTextDrawShow(playerid, pData[playerid][P_ClickGuideW]);
	return 1;
}

stock HideClickAreaOverlay(playerid)
{
	if(pData[playerid][P_ClickAreaOverlay] != INVALID_PLAYER_TEXT_DRAW)
	{
		PlayerTextDrawDestroy(playerid, pData[playerid][P_ClickAreaOverlay]);
		pData[playerid][P_ClickAreaOverlay] = INVALID_PLAYER_TEXT_DRAW;
	}
	if(pData[playerid][P_ClickGuideW] != INVALID_PLAYER_TEXT_DRAW)
	{
		PlayerTextDrawDestroy(playerid, pData[playerid][P_ClickGuideW]);
		pData[playerid][P_ClickGuideW] = INVALID_PLAYER_TEXT_DRAW;
	}
	if(pData[playerid][P_ClickGuideH] != INVALID_PLAYER_TEXT_DRAW)
	{
		PlayerTextDrawDestroy(playerid, pData[playerid][P_ClickGuideH]);
		pData[playerid][P_ClickGuideH] = INVALID_PLAYER_TEXT_DRAW;
	}
	return 1;
}

// HTML color presets (complete list from provided article)
#define COLOR_PRESET_PAGE_SIZE 30

enum HTMLColorEntry { HTMLColorName[24], HTMLColorHex[8], HTMLColorRGBA };
new HTML_COLORS[][HTMLColorEntry] = {
	{"Snow", "#FFFAFA", 0xFFFAFAFF},
	{"GhostWhite", "#F8F8FF", 0xF8F8FFFF},
	{"WhiteSmoke", "#F5F5F5", 0xF5F5F5FF},
	{"Gainsboro", "#DCDCDC", 0xDCDCDCFF},
	{"FloralWhite", "#FFFAF0", 0xFFFAF0FF},
	{"OldLace", "#FDF5E6", 0xFDF5E6FF},
	{"Linen", "#FAF0E6", 0xFAF0E6FF},
	{"AntiqueWhite", "#FAEBD7", 0xFAEBD7FF},
	{"PapayaWhip", "#FFEFD5", 0xFFEFD5FF},
	{"BlanchedAlmond", "#FFEBCD", 0xFFEBCDFF},
	{"Bisque", "#FFE4C4", 0xFFE4C4FF},
	{"PeachPuff", "#FFDAB9", 0xFFDAB9FF},
	{"NavajoWhite", "#FFDEAD", 0xFFDEADFF},
	{"Moccasin", "#FFE4B5", 0xFFE4B5FF},
	{"Cornsilk", "#FFF8DC", 0xFFF8DCFF},
	{"Ivory", "#FFFFF0", 0xFFFFF0FF},
	{"LemonChiffon", "#FFFACD", 0xFFFACDFF},
	{"Seashell", "#FFF5EE", 0xFFF5EEFF},
	{"Honeydew", "#F0FFF0", 0xF0FFF0FF},
	{"MintCream", "#F5FFFA", 0xF5FFFAFF},
	{"Azure", "#F0FFFF", 0xF0FFFFFF},
	{"AliceBlue", "#F0F8FF", 0xF0F8FFFF},
	{"Lavender", "#E6E6FA", 0xE6E6FAFF},
	{"LavenderBlush", "#FFF0F5", 0xFFF0F5FF},
	{"MistyRose", "#FFE4E1", 0xFFE4E1FF},
	{"White", "#FFFFFF", 0xFFFFFFFF},
	{"Black", "#000000", 0x000000FF},
	{"DarkSlateGray", "#2F4F4F", 0x2F4F4FFF},
	{"DimGrey", "#696969", 0x696969FF},
	{"SlateGrey", "#708090", 0x708090FF},
	{"LightSlateGray", "#778899", 0x778899FF},
	{"Grey", "#BEBEBE", 0xBEBEBEFF},
	{"LightGray", "#D3D3D3", 0xD3D3D3FF},
	{"MidnightBlue", "#191970", 0x191970FF},
	{"NavyBlue", "#000080", 0x000080FF},
	{"CornflowerBlue", "#6495ED", 0x6495EDFF},
	{"DarkSlateBlue", "#483D8B", 0x483D8BFF},
	{"SlateBlue", "#6A5ACD", 0x6A5ACDFF},
	{"MediumSlateBlue", "#7B68EE", 0x7B68EEFF},
	{"LightSlateBlue", "#8470FF", 0x8470FFFF},
	{"MediumBlue", "#0000CD", 0x0000CDFF},
	{"RoyalBlue", "#4169E1", 0x4169E1FF},
	{"Blue", "#0000FF", 0x0000FFFF},
	{"DodgerBlue", "#1E90FF", 0x1E90FFFF},
	{"DeepSkyBlue", "#00BFFF", 0x00BFFFFF},
	{"SkyBlue", "#87CEEB", 0x87CEEBFF},
	{"LightSkyBlue", "#87CEFA", 0x87CEFAFF},
	{"SteelBlue", "#4682B4", 0x4682B4FF},
	{"LightSteelBlue", "#B0C4DE", 0xB0C4DEFF},
	{"LightBlue", "#ADD8E6", 0xADD8E6FF},
	{"PowderBlue", "#B0E0E6", 0xB0E0E6FF},
	{"PaleTurquoise", "#AFEEEE", 0xAFEEEEFF},
	{"DarkTurquoise", "#00CED1", 0x00CED1FF},
	{"MediumTurquoise", "#48D1CC", 0x48D1CCFF},
	{"Turquoise", "#40E0D0", 0x40E0D0FF},
	{"Cyan", "#00FFFF", 0x00FFFFFF},
	{"LightCyan", "#E0FFFF", 0xE0FFFFFF},
	{"CadetBlue", "#5F9EA0", 0x5F9EA0FF},
	{"MediumAquamarine", "#66CDAA", 0x66CDAAFF},
	{"Aquamarine", "#7FFFD4", 0x7FFFD4FF},
	{"DarkGreen", "#006400", 0x006400FF},
	{"DarkOliveGreen", "#556B2F", 0x556B2FFF},
	{"DarkSeaGreen", "#8FBC8F", 0x8FBC8FFF},
	{"SeaGreen", "#2E8B57", 0x2E8B57FF},
	{"MediumSeaGreen", "#3CB371", 0x3CB371FF},
	{"LightSeaGreen", "#20B2AA", 0x20B2AAFF},
	{"PaleGreen", "#98FB98", 0x98FB98FF},
	{"SpringGreen", "#00FF7F", 0x00FF7FFF},
	{"LawnGreen", "#7CFC00", 0x7CFC00FF},
	{"Green", "#00FF00", 0x00FF00FF},
	{"Chartreuse", "#7FFF00", 0x7FFF00FF},
	{"MedSpringGreen", "#00FA9A", 0x00FA9AFF},
	{"GreenYellow", "#ADFF2F", 0xADFF2FFF},
	{"LimeGreen", "#32CD32", 0x32CD32FF},
	{"YellowGreen", "#9ACD32", 0x9ACD32FF},
	{"ForestGreen", "#228B22", 0x228B22FF},
	{"OliveDrab", "#6B8E23", 0x6B8E23FF},
	{"DarkKhaki", "#BDB76B", 0xBDB76BFF},
	{"PaleGoldenrod", "#EEE8AA", 0xEEE8AAFF},
	{"LightGoldenrodYellow", "#FAFAD2", 0xFAFAD2FF},
	{"LightYellow", "#FFFFE0", 0xFFFFE0FF},
	{"Yellow", "#FFFF00", 0xFFFF00FF},
	{"Gold", "#FFD700", 0xFFD700FF},
	{"LightGoldenrod", "#EEDD82", 0xEEDD82FF},
	{"goldenrod", "#DAA520", 0xDAA520FF},
	{"DarkGoldenrod", "#B8860B", 0xB8860BFF},
	{"RosyBrown", "#BC8F8F", 0xBC8F8FFF},
	{"IndianRed", "#CD5C5C", 0xCD5C5CFF},
	{"SaddleBrown", "#8B4513", 0x8B4513FF},
	{"Sienna", "#A0522D", 0xA0522DFF},
	{"Peru", "#CD853F", 0xCD853FFF},
	{"Burlywood", "#DEB887", 0xDEB887FF},
	{"Beige", "#F5F5DC", 0xF5F5DCFF},
	{"Wheat", "#F5DEB3", 0xF5DEB3FF},
	{"SandyBrown", "#F4A460", 0xF4A460FF},
	{"Tan", "#D2B48C", 0xD2B48CFF},
	{"Chocolate", "#D2691E", 0xD2691EFF},
	{"Firebrick", "#B22222", 0xB22222FF},
	{"Brown", "#A52A2A", 0xA52A2AFF},
	{"DarkSalmon", "#E9967A", 0xE9967AFF},
	{"Salmon", "#FA8072", 0xFA8072FF},
	{"LightSalmon", "#FFA07A", 0xFFA07AFF},
	{"Orange", "#FFA500", 0xFFA500FF},
	{"DarkOrange", "#FF8C00", 0xFF8C00FF},
	{"Coral", "#FF7F50", 0xFF7F50FF},
	{"LightCoral", "#F08080", 0xF08080FF},
	{"Tomato", "#FF6347", 0xFF6347FF},
	{"OrangeRed", "#FF4500", 0xFF4500FF},
	{"Red", "#FF0000", 0xFF0000FF},
	{"HotPink", "#FF69B4", 0xFF69B4FF},
	{"DeepPink", "#FF1493", 0xFF1493FF},
	{"Pink", "#FFC0CB", 0xFFC0CBFF},
	{"LightPink", "#FFB6C1", 0xFFB6C1FF},
	{"PaleVioletRed", "#DB7093", 0xDB7093FF},
	{"Maroon", "#B03060", 0xB03060FF},
	{"MediumVioletRed", "#C71585", 0xC71585FF},
	{"VioletRed", "#D02090", 0xD02090FF},
	{"Magenta", "#FF00FF", 0xFF00FFFF},
	{"Violet", "#EE82EE", 0xEE82EEFF},
	{"Plum", "#DDA0DD", 0xDDA0DDFF},
	{"Orchid", "#DA70D6", 0xDA70D6FF},
	{"MediumOrchid", "#BA55D3", 0xBA55D3FF},
	{"DarkOrchid", "#9932CC", 0x9932CCFF},
	{"DarkViolet", "#9400D3", 0x9400D3FF},
	{"BlueViolet", "#8A2BE2", 0x8A2BE2FF},
	{"Purple", "#A020F0", 0xA020F0FF},
	{"MediumPurple", "#9370DB", 0x9370DBFF},
	{"Thistle", "#D8BFD8", 0xD8BFD8FF},
	{"Snow1", "#FFFAFA", 0xFFFAFAFF}
};

new HTML_COLOR_NAMES_PT[][32] = {
	"Neve",
	"Branco fantasma",
	"Fumaca branca",
	"Gainsboro",
	"Branco floral",
	"Renda antiga",
	"Linho",
	"Branco antigo",
	"Creme de mamao",
	"Amendoa clara",
	"Bisque",
	"Pessego claro",
	"Branco Navajo",
	"Mocassim",
	"Seda de milho",
	"Marfim",
	"Chiffon de limao",
	"Concha do mar",
	"Melao",
	"Creme de menta",
	"Azul celeste",
	"Azul Alice",
	"Lavanda",
	"Rubor de lavanda",
	"Rosa enevoado",
	"Branco",
	"Preto",
	"Cinza ardosia escuro",
	"Cinza fraco",
	"Cinza ardosia",
	"Cinza ardosia claro",
	"Cinza",
	"Cinza claro",
	"Azul meia noite",
	"Azul marinho",
	"Azul centaurea",
	"Azul ardosia escuro",
	"Azul ardosia",
	"Azul ardosia medio",
	"Azul ardosia claro",
	"Azul medio",
	"Azul royal",
	"Azul",
	"Azul dodger",
	"Azul ceu profundo",
	"Azul ceu",
	"Azul ceu claro",
	"Azul aco",
	"Azul aco claro",
	"Azul claro",
	"Azul po",
	"Turquesa palido",
	"Turquesa escuro",
	"Turquesa medio",
	"Turquesa",
	"Ciano",
	"Ciano claro",
	"Azul cadete",
	"Agua marinha media",
	"Agua marinha",
	"Verde escuro",
	"Verde oliva escuro",
	"Verde mar escuro",
	"Verde mar",
	"Verde mar medio",
	"Verde mar claro",
	"Verde palido",
	"Verde primavera",
	"Verde gramado",
	"Verde",
	"Chartreuse",
	"Verde primavera medio",
	"Verde amarelado",
	"Verde lima",
	"Amarelo esverdeado",
	"Verde floresta",
	"Verde oliva queimado",
	"Caqui escuro",
	"Goldenrod palido",
	"Amarelo goldenrod claro",
	"Amarelo claro",
	"Amarelo",
	"Ouro",
	"Goldenrod claro",
	"Goldenrod",
	"Goldenrod escuro",
	"Marrom rosado",
	"Vermelho indiano",
	"Marrom sela",
	"Siena",
	"Peru",
	"Madeira clara",
	"Bege",
	"Trigo",
	"Marrom areia",
	"Bronzeado",
	"Chocolate",
	"Tijolo refratario",
	"Marrom",
	"Salmao escuro",
	"Salmao",
	"Salmao claro",
	"Laranja",
	"Laranja escuro",
	"Coral",
	"Coral claro",
	"Tomate",
	"Vermelho alaranjado",
	"Vermelho",
	"Rosa choque",
	"Rosa profundo",
	"Rosa",
	"Rosa claro",
	"Vermelho violeta palido",
	"Bordo",
	"Vermelho violeta medio",
	"Vermelho violeta",
	"Magenta",
	"Violeta",
	"Ameixa",
	"Orquidea",
	"Orquidea media",
	"Orquidea escura",
	"Violeta escuro",
	"Azul violeta",
	"Roxo",
	"Roxo medio",
	"Cardo",
	"Neve 1"
};
// =============================================================================
// Callbacks.
// =============================================================================
public OnFilterScriptInit()
{
	print("\n--------------------------------------");
	print(" Text Draw Editor 1.0RC2 by Zamaroht for SA-MP 0.3 Loaded.");
	print("--------------------------------------\n");
	for(new i; i < MAX_PLAYERS; i ++) if(IsPlayerConnected(i)) ResetPlayerVars(i);
	for(new i; i < MAX_TEXTDRAWS; i ++)
	{
	    tData[i][T_Handler] = TextDrawCreate(0.0, 0.0, " ");
	    tData[i][T_PreviewModel] = -1;
		tData[i][PMZoom] = 1.0;
		tData[i][PMRotX] = -16.0;
		tData[i][PMRotY] = 0.0;
		tData[i][PMRotZ] = -55.0;
	}
	return 1;
}

public OnFilterScriptExit()
{
    for(new i; i < MAX_TEXTDRAWS; i ++)
	{
	    TextDrawHideForAll(tData[i][T_Handler]);
	    TextDrawDestroy(tData[i][T_Handler]);
	}
	return 1;
}

public OnPlayerClickTextDraw(playerid, Text:clickedid)
{
    if(!pData[playerid][P_ClickTestMode]) return 0;
    if(clickedid == Text:65535)
    {
        // ESC pressed: disable click-test mode
        pData[playerid][P_ClickTestMode] = false;
        CancelSelectTextDraw(playerid);
        SendClientMessage(playerid, MSG_COLOR, "Click-test DESATIVADO.");
        return 1;
    }
    SendClientMessage(playerid, MSG_COLOR, "Clique em TD (global) detectado.");
    return 1;
}

public OnPlayerClickPlayerTextDraw(playerid, PlayerText:playertextid)
{
    if(!pData[playerid][P_ClickTestMode]) return 0;
    SendClientMessage(playerid, MSG_COLOR, "Clique em TD (player) detectado.");
    return 1;
}

public OnPlayerConnect(playerid)
{
	for(new i; i < MAX_TEXTDRAWS; i ++)
	{
	    if(tData[i][T_Created])
	        TextDrawShowForPlayer(playerid, tData[i][T_Handler]);
	}
}

public OnPlayerSpawn(playerid)
{
	SendClientMessage(playerid, MSG_COLOR, "Use /text para abrir o menu de edicao");
	
	return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
    ResetPlayerVars(playerid);
	return 1;
}


CMD:text(playerid, params[])
{
	if(pData[playerid][P_Editing])
	{
		// Ja em modo de edicao: reabrir o dialogo correspondente em vez de bloquear
		if(!strlen(CurrentProject) || !strcmp(CurrentProject, " "))
		{
			ShowTextDrawDialog(playerid, 0);
		}
		else
		{
			ShowTextDrawDialog(playerid, 4, 0);
		}
		return 1;
	}
	else if(!strlen(CurrentProject) || !strcmp(CurrentProject, " "))
	{
		if(IsPlayerMinID(playerid))
		{
			ShowTextDrawDialog(playerid, 0);
			pData[playerid][P_Editing] = true;
		}
		else
			SendClientMessage(playerid, MSG_COLOR, "Apenas o menor ID online pode gerenciar projetos. Peca para ele abrir um.");
		return 1;
	}
	else
	{
		ShowTextDrawDialog(playerid, 4, 0);
		pData[playerid][P_Editing] = true;
		return 1;
	}
}

CMD:tdtest(playerid, params[])
{
	if(!pData[playerid][P_ClickTestMode])
	{
		pData[playerid][P_ClickTestMode] = true;
		SelectTextDraw(playerid, pData[playerid][P_SelectColor]);
		SendClientMessage(playerid, MSG_COLOR, "Click-test ATIVADO. Pressione ESC para desativar.");
	}
	else
	{
		SendClientMessage(playerid, MSG_COLOR, "Click-test JA ESTA ATIVADO. Pressione ESC ou use /tdcancel.");
	}
	return 1;
}

CMD:tdcancel(playerid, params[])
{
	if(pData[playerid][P_ClickTestMode])
	{
		pData[playerid][P_ClickTestMode] = false;
		CancelSelectTextDraw(playerid);
		SendClientMessage(playerid, MSG_COLOR, "Click-test DESATIVADO.");
	}
	else
	{
		SendClientMessage(playerid, MSG_COLOR, "Click-test ja esta desativado.");
	}
	return 1;
}

// /tdselcolor <#RRGGBB|RRGGBB|#RRGGBBAA|0xRRGGBBAA>
CMD:tdselcolor(playerid, params[])
{
	new arg[32];
	strmid(arg, params, 0, strlen(params), sizeof(arg));
	while(arg[0] == ' ') strdel(arg, 0, 1);
	if(!strlen(arg)) { SendClientMessage(playerid, MSG_COLOR, "Uso: /tdselcolor #RRGGBB ou RRGGBB ou #RRGGBBAA ou 0xRRGGBBAA"); return 1; }

	new red[3], green[3], blue[3], alpha[3];
	new len = strlen(arg);
	if(arg[0] == '0' && arg[1] == 'x')
	{
		if(len != 8 && len != 10) { SendClientMessage(playerid, MSG_COLOR, "Formato invalido. Use 0xRRGGBB ou 0xRRGGBBAA."); return 1; }
		format(red, sizeof(red), "%c%c", arg[2], arg[3]);
		format(green, sizeof(green), "%c%c", arg[4], arg[5]);
		format(blue, sizeof(blue), "%c%c", arg[6], arg[7]);
		if(len == 10) format(alpha, sizeof(alpha), "%c%c", arg[8], arg[9]); else alpha = "FF";
	}
	else if(arg[0] == '#')
	{
		if(len != 7 && len != 9) { SendClientMessage(playerid, MSG_COLOR, "Formato invalido. Use #RRGGBB ou #RRGGBBAA."); return 1; }
		format(red, sizeof(red), "%c%c", arg[1], arg[2]);
		format(green, sizeof(green), "%c%c", arg[3], arg[4]);
		format(blue, sizeof(blue), "%c%c", arg[5], arg[6]);
		if(len == 9) format(alpha, sizeof(alpha), "%c%c", arg[7], arg[8]); else alpha = "FF";
	}
	else
	{
		if(len != 6 && len != 8) { SendClientMessage(playerid, MSG_COLOR, "Formato invalido. Use RRGGBB ou RRGGBBAA."); return 1; }
		format(red, sizeof(red), "%c%c", arg[0], arg[1]);
		format(green, sizeof(green), "%c%c", arg[2], arg[3]);
		format(blue, sizeof(blue), "%c%c", arg[4], arg[5]);
		if(len == 8) format(alpha, sizeof(alpha), "%c%c", arg[6], arg[7]); else alpha = "FF";
	}

	new selcol = RGB(HexToInt(red), HexToInt(green), HexToInt(blue), HexToInt(alpha));
	pData[playerid][P_SelectColor] = selcol;
	if(pData[playerid][P_ClickTestMode])
	{
		CancelSelectTextDraw(playerid);
		SelectTextDraw(playerid, pData[playerid][P_SelectColor]);
	}
	SendClientMessage(playerid, MSG_COLOR, "Cor de selecao atualizada para o Click-test.");
	return 1;
}
// /tdarea <largura> <altura> (opcionalmente via dialog se vazio)
CMD:tdarea(playerid, params[])
{
	if(strlen(params))
	{
		new args[64];
		strmid(args, params, 0, strlen(params), sizeof(args));
		while(args[0] == ' ') strdel(args, 0, 1);
		if(strlen(args))
		{
			new a1[24], a2[24];
			new p = strfind(args, " ");
			if(p != -1)
			{
				strmid(a1, args, 0, p, sizeof(a1));
				strmid(a2, args, p + 1, strlen(args), sizeof(a2));
				while(a2[0] == ' ') strdel(a2, 0, 1);
				if(IsNumeric2(a1) && IsNumeric2(a2))
				{
					new Float:w = floatstr(a1);
					new Float:h = floatstr(a2);
					tData[pData[playerid][P_CurrentTextdraw]][T_TextSizeX] = w;
					tData[pData[playerid][P_CurrentTextdraw]][T_TextSizeY] = h;
					UpdateTextdraw(pData[playerid][P_CurrentTextdraw]);
					SaveTDData(pData[playerid][P_CurrentTextdraw], "T_TextSizeX");
					SaveTDData(pData[playerid][P_CurrentTextdraw], "T_TextSizeY");
					if(pData[playerid][P_ClickAreaOverlayEnabled]) RebuildClickAreaOverlay(playerid);
					new s[128];
					format(s, sizeof(s), "Area de clique ajustada: X %.2f, Y %.2f", w, h);
					SendClientMessage(playerid, MSG_COLOR, s);
					return 1;
				}
			}
		}
	}
	new string[128];
	format(string, sizeof(string), "Digite a largura da area de clique (atual: %.2f):", tData[pData[playerid][P_CurrentTextdraw]][T_TextSizeX]);
	ShowPlayerDialog(playerid, 2000, DIALOG_STYLE_INPUT, "Area de Clique - Largura", string, "Proximo", "Cancelar");
	return 1;
}

CMD:tdstatus(playerid, params[])
{
	new s[196];
	format(s, sizeof(s), "Overlay area de clique: %s | Click-test: %s | Selecionavel: %s", pData[playerid][P_ClickAreaOverlayEnabled] ? ("ATIVADO") : ("DESATIVADO"), pData[playerid][P_ClickTestMode] ? ("ATIVADO") : ("DESATIVADO"), tData[pData[playerid][P_CurrentTextdraw]][T_Selectable] ? ("ATIVADO") : ("DESATIVADO"));
	SendClientMessage(playerid, MSG_COLOR, s);
	return 1;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    if(response == 1) 	PlayerPlaySound(playerid, 1083, 0.0, 0.0, 0.0); // Confirmation sound
    else 				PlayerPlaySound(playerid, 1084, 0.0, 0.0, 0.0); // Cancelation sound
    
    switch(dialogid)
    {
        case 1574: // First dialog.
        {
            if(response) // If he pressed accept.
            {
                strmid(CurrentProject, "", 0, 1, 128);
                
                if(listitem == 0) // He pressed new project.
                    ShowTextDrawDialog(playerid, 1);
                else if(listitem == 1) // He pressed load project.
                    ShowTextDrawDialog(playerid, 2, 1);
                else if(listitem == 2) // He pressed delete project.
                    ShowTextDrawDialog(playerid, 2, 2);
            }
            else pData[playerid][P_Editing] = false;
        }
        
        case 1575: // New Project
        {
            if(response)
            {
                if(strlen(inputtext) > 120) ShowTextDrawDialog(playerid, 1, 1); // Too long.
                
                else if(
					strfind(inputtext, "/") != -1 || strfind(inputtext, "\\") != -1 ||
					strfind(inputtext, ":") != -1 || strfind(inputtext, "*") != -1 ||
					strfind(inputtext, "?") != -1 || strfind(inputtext, "\"") != -1 ||
					strfind(inputtext, "<") != -1 || strfind(inputtext, ">") != -1 ||
					strfind(inputtext, "|") != -1 || !strlen(inputtext) ||
					inputtext[0] == ' ' )
						ShowTextDrawDialog(playerid, 1, 3); // Ilegal characters.
						
                else // It's ok, create the new file.
                {
                    new filename[128];
                    format(filename, sizeof(filename), "%s.tde", inputtext);
                    if(fexist(filename)) ShowTextDrawDialog(playerid, 1, 2); // Already exists.
                    else
                    {
	                    CreateNewProject(filename);
	                    strmid(CurrentProject, filename, 0, strlen(inputtext), 128);
	                    
	                    new tmpstr[128];
	                    format(tmpstr, sizeof(tmpstr), "Voce agora esta trabalhando no projeto '%s'.", filename);
	                    SendClientMessage(playerid, MSG_COLOR, tmpstr);
	                    
	                    ShowTextDrawDialog(playerid, 4); // Show the main edition menu.
			 		}
                }
            }
            else
                ShowTextDrawDialog(playerid, 0);
        }
        
        case 1576: // Load/Delete project
        {
            if(response)
            {
                if(listitem == 0) // Custom filename
                {
                    if(pData[playerid][P_CurrentMenu] == LOADING)		ShowTextDrawDialog(playerid, 3);
                    else if(pData[playerid][P_CurrentMenu] == DELETING)	ShowTextDrawDialog(playerid, 0);
				}
				else
				{
				    if(pData[playerid][P_CurrentMenu] == DELETING)
				    {
				        pData[playerid][P_Aux] = listitem - 1;
				        ShowTextDrawDialog(playerid, 6);
					}
					else if(pData[playerid][P_CurrentMenu] == LOADING)
					{
					    new filename[135];
					    format(filename, sizeof(filename), "%s", GetFileNameFromLst("tdlist.lst", listitem - 1));
					    LoadProject(playerid, filename);
					}
                }
            }
            else
                ShowTextDrawDialog(playerid, 0);
        }
        
        case 1577: // Load custom project
        {
			if(response)
			{
				new ending[5];
				strmid(ending, inputtext, strlen(inputtext) - 4, strlen(inputtext));
				if(strcmp(ending, ".tde") != 0)
				{
				    new filename[128];
				    format(filename, sizeof(filename), "%s.tde", inputtext);
				    LoadProject(playerid, filename);
				}
				else LoadProject(playerid, inputtext);
			}
			else
			{
			    if(pData[playerid][P_CurrentMenu] == DELETING)		ShowTextDrawDialog(playerid, 2, 2);
			    else if(pData[playerid][P_CurrentMenu] == LOADING)	ShowTextDrawDialog(playerid, 2);
			}
        }
        
        case 1578: // Textdraw selection
        {
            if(response)
            {
                if(listitem == 0) // They selected new textdraw
                {
                    pData[playerid][P_CurrentTextdraw] = -1;
                    for(new i; i < MAX_TEXTDRAWS; i++)
                    {
                        if(!tData[i][T_Created]) // If it isn't created yet, use it.
                        {
                            ClearTextdraw(i);
                            CreateDefaultTextdraw(i);
                            pData[playerid][P_CurrentTextdraw] = i;
                            ShowTextDrawDialog(playerid, 4, pData[playerid][P_DialogPage]);
                            break;
                        }
					}
					if(pData[playerid][P_CurrentTextdraw] == -1)
					{
					    SendClientMessage(playerid, MSG_COLOR, "Voce nao pode criar mais textdraws!");
					    ShowTextDrawDialog(playerid, 4, pData[playerid][P_DialogPage]);
					}
										else
					{
						new string[128];
			            format(string, sizeof(string), "Textdraw #%d criada com sucesso.", pData[playerid][P_CurrentTextdraw]);
			            SendClientMessage(playerid, MSG_COLOR, string);
					}
                }
                else if(listitem == 1) // They selected export
                {
                    ShowTextDrawDialog(playerid, 25);
                }
                else if(listitem == 2) // They selected close project
                {
                    if(IsPlayerMinID(playerid))
                    {
	                    for(new i; i < MAX_TEXTDRAWS; i ++)
	                    {
	                        ClearTextdraw(i);
	                    }

	                    new string[128];
	                    format(string, sizeof(string), "Project '%s' closed.", CurrentProject);
	                    SendClientMessage(playerid, MSG_COLOR, string);

	                    strmid(CurrentProject, " ", 128, 128);
	                    HideClickAreaOverlay(playerid);
	                    ShowTextDrawDialog(playerid, 0);
					}
					else
					{
					    SendClientMessage(playerid, MSG_COLOR, "Apenas o menor ID online pode gerenciar projetos. Peca para ele abrir um.");
					    ShowTextDrawDialog(playerid, 4);
					}
                }
                else if(listitem <= 10) // They selected a TD
                {
                    new id = 3;
                    for(new i = pData[playerid][P_DialogPage]; i < MAX_TEXTDRAWS; i ++)
                    {
                        if(tData[i][T_Created])
                        {
                            if(id == listitem)
                            {
                                // We found it
                                pData[playerid][P_CurrentTextdraw] = i;
                                if(pData[playerid][P_ClickAreaOverlayEnabled]) RebuildClickAreaOverlay(playerid);
                                ShowTextDrawDialog(playerid, 5);
                                break;
                            }
                            id ++;
                        }
                    }
                    new string[128];
                    format(string, sizeof(string), "Você está editando a textdraw #%d", pData[playerid][P_CurrentTextdraw]);
                    SendClientMessage(playerid, MSG_COLOR, string);
                }
                else
                {
                    new BiggestID, itemcount;
                    for(new i = pData[playerid][P_DialogPage]; i < MAX_TEXTDRAWS; i ++)
                    {
                        if(tData[i][T_Created])
                        {
							itemcount ++;
							BiggestID = i;
							if(itemcount == 9) break;
						}
                    }
                    ShowTextDrawDialog(playerid, 4, BiggestID);
				}
            }
            else
            {
                pData[playerid][P_Editing] = false;
                pData[playerid][P_DialogPage] = 0;
            }
        }
        
        case 1579: // Main edition menu
        {
            if(response)
            {
                switch(listitem)
                {
                    case 0: // Change text
	                {
                        ShowTextDrawDialog(playerid, 8);
	                }
	                case 1: // Change position
	                {
	                    ShowTextDrawDialog(playerid, 9);
	                }
	                case 2: // Change alignment
	                {
	                    ShowTextDrawDialog(playerid, 11);
	                }
	                case 3: // Change font color
	                {
	                    pData[playerid][P_ColorEdition] = COLOR_TEXT;
	                    ShowTextDrawDialog(playerid, 13);
	                }
	                case 4: // Change font
	                {
	                    ShowTextDrawDialog(playerid, 17);
	                }
	                case 5: // Change proportionality
	                {
	                    ShowTextDrawDialog(playerid, 12);
	                }
	                case 6: // Change letter size
	                {
	                    ShowTextDrawDialog(playerid, 18);
	                }
	                case 7: // Edit outline
	                {
	                    ShowTextDrawDialog(playerid, 20);
	                }
	                case 8: // Edit box
	                {
	                    if(tData[pData[playerid][P_CurrentTextdraw]][T_UseBox] == 0)		ShowTextDrawDialog(playerid, 23);
	                    else if(tData[pData[playerid][P_CurrentTextdraw]][T_UseBox] == 1)	ShowTextDrawDialog(playerid, 24);
	                }
	                                case 9: // Edit click area (TextSize)
                {
                    new string[128];
                    format(string, sizeof(string), "Digite a largura da area de clique (atual: %.2f):", tData[pData[playerid][P_CurrentTextdraw]][T_TextSizeX]);
                    ShowPlayerDialog(playerid, 2000, DIALOG_STYLE_INPUT, "Area de Clique - Largura", string, "Proximo", "Cancelar");
                }
	                case 10: // Toggle click-test mode
	                {
	                    pData[playerid][P_ClickTestMode] = !pData[playerid][P_ClickTestMode];
	                    if(pData[playerid][P_ClickTestMode]) SelectTextDraw(playerid, pData[playerid][P_SelectColor]);
	                    else CancelSelectTextDraw(playerid);
	                    new string[96];
	                    format(string, sizeof(string), "Click-test %s.", pData[playerid][P_ClickTestMode] ? ("ATIVADO") : ("DESATIVADO"));
	                    SendClientMessage(playerid, MSG_COLOR, string);
	                    ShowTextDrawDialog(playerid, 5);
	                }
	                case 11: // Textdraw mode
	                {
                        ShowTextDrawDialog(playerid, 39);
	                }
	                case 12: // TextDrawSetSelectable
	                {
	                    ShowTextDrawDialog(playerid, 32);
	                }
	                case 13: // PreviewModel
	                {
                       	ShowTextDrawDialog(playerid, 33);
	                }
	                case 14: // Duplicate textdraw
	                {
	                    new from, to;
	                    for(new i; i < MAX_TEXTDRAWS; i++)
	                    {
	                        if(!tData[i][T_Created]) // If it isn't created yet, use it.
	                        {
	                            ClearTextdraw(i);
	                            CreateDefaultTextdraw(i);
	                            from = pData[playerid][P_CurrentTextdraw];
	                            to = i;
	                            DuplicateTextdraw(pData[playerid][P_CurrentTextdraw], i);
	                            pData[playerid][P_CurrentTextdraw] = -1;
	                            ShowTextDrawDialog(playerid, 4);
	                            break;
	                        }
						}
											if(pData[playerid][P_CurrentTextdraw] != -1)
					{
					    					SendClientMessage(playerid, MSG_COLOR, "Voce nao pode criar mais textdraws!");
					ShowTextDrawDialog(playerid, 5);
						}
											else
					{
						new string[128];
			            format(string, sizeof(string), "Textdraw #%d copiada com sucesso para a Textdraw #%d.", from, to);
			            SendClientMessage(playerid, MSG_COLOR, string);
					}
	                }
	                case 15: // Delete textdraw
	                {
                        ShowTextDrawDialog(playerid, 7);
	                }
				}
            }
            else
			{
			    ShowTextDrawDialog(playerid, 4, 0);
			}
        }
        
        case 1580: // Delete project confirmation dialog
        {
            if(response)
            {
                new filename[128];
                format(filename, sizeof(filename), "%s", GetFileNameFromLst("tdlist.lst", pData[playerid][P_Aux]));
	            fremove(filename);
				DeleteLineFromFile("tdlist.lst", pData[playerid][P_Aux]);
				
				format(filename, sizeof(filename), "O projeto salvo como '%s' foi excluído com sucesso.", filename);
				SendClientMessage(playerid, MSG_COLOR, filename);
				
				ShowTextDrawDialog(playerid, 0);
			}
			else
			{
			    ShowTextDrawDialog(playerid, 0);
			}
        }
        
        case 1581: // Delete TD confirmation
        {
            if(response)
            {
                DeleteTDFromFile(pData[playerid][P_CurrentTextdraw]);
				ClearTextdraw(pData[playerid][P_CurrentTextdraw]);
                
                new string[128];
                format(string, sizeof(string), "You have deleted textdraw #%d", pData[playerid][P_CurrentTextdraw]);
                SendClientMessage(playerid, MSG_COLOR, string);
                
                pData[playerid][P_CurrentTextdraw] = 0;
                ShowTextDrawDialog(playerid, 4);
            }
            else
            {
                ShowTextDrawDialog(playerid, 5);
            }
        }
        
        case 1582: // Change textdraw's text
        {
            if(response)
            {
                if(!strlen(inputtext)) ShowTextDrawDialog(playerid, 8);
                else
                {
	                format(tData[pData[playerid][P_CurrentTextdraw]][T_Text], 1024, "%s", inputtext);
	                UpdateTextdraw(pData[playerid][P_CurrentTextdraw]);
	                SaveTDData(pData[playerid][P_CurrentTextdraw], "T_Text");
	                ShowTextDrawDialog(playerid, 5);
				}
            }
            else
            {
                ShowTextDrawDialog(playerid, 5);
            }
        }
        
        case 1583: // Change textdraw's position: exact or move
        {
            if(response)
            {
                switch(listitem)
                {
                    case 0: // Exact position
                    {
                        pData[playerid][P_Aux] = 0;
                        ShowTextDrawDialog(playerid, 10, 0, 0);
                    }
                    case 1: // Move it
                    {
                        new string[512];
                        string = "~n~~n~~n~~n~~n~~n~~n~~n~~w~";
                        if(!IsPlayerInAnyVehicle(playerid))	format(string, sizeof(string), "%s~k~~GO_FORWARD~, ~k~~GO_BACK~, ~k~~GO_LEFT~, ~k~~GO_RIGHT~~n~", string);
						else								format(string, sizeof(string), "%s~k~~VEHICLE_STEERUP~, ~k~~VEHICLE_STEERDOWN~, ~k~~VEHICLE_STEERLEFT~, ~k~~VEHICLE_STEERRIGHT~~n~", string);
						format(string, sizeof(string), "%sand ~k~~PED_SPRINT~ to move. ", string);
						if(!IsPlayerInAnyVehicle(playerid))	format(string, sizeof(string), "%s~k~~VEHICLE_ENTER_EXIT~", string);
						else								format(string, sizeof(string), "%s~k~~VEHICLE_FIREWEAPON_ALT~", string);
						format(string, sizeof(string), "%s to finish.~n~", string);
						
						GameTextForPlayer(playerid, string, 9999999, 3);
						SendClientMessage(playerid, MSG_COLOR, "Use [cima], [baixo], [esquerda] e [direita] para mover a textdraw. [sprint] acelera e [entrar veículo] finaliza.");
						
						TogglePlayerControllable(playerid, 0);
						pData[playerid][P_KeyEdition] = EDIT_POSITION;
						SetTimerEx("KeyEdit", 200, 0, "i", playerid);
                    }
                }
            }
            else
            {
                ShowTextDrawDialog(playerid, 5);
            }
        }
        
        case 1584: // Set position manually
        {
            if(response)
            {
                if(!IsNumeric2(inputtext)) ShowTextDrawDialog(playerid, 10, pData[playerid][P_Aux], 1);
                else
                {
                    if(pData[playerid][P_Aux] == 0) // If he edited X
                    {
                        tData[pData[playerid][P_CurrentTextdraw]][T_X] = floatstr(inputtext);
                        UpdateTextdraw(pData[playerid][P_CurrentTextdraw]);
                        SaveTDData(pData[playerid][P_CurrentTextdraw], "T_X");
                        ShowTextDrawDialog(playerid, 10, 1, 0);
                    }
                    else if(pData[playerid][P_Aux] == 1) // If he edited Y
                    {
                        tData[pData[playerid][P_CurrentTextdraw]][T_Y] = floatstr(inputtext);
                        UpdateTextdraw(pData[playerid][P_CurrentTextdraw]);
                        SaveTDData(pData[playerid][P_CurrentTextdraw], "T_Y");
                        ShowTextDrawDialog(playerid, 5);
                        
						SendClientMessage(playerid, MSG_COLOR, "Textdraw movida com sucesso.");
                    }
                }
            }
            else
            {
                if(pData[playerid][P_Aux] == 1) // If he is editing Y, move him to X.
                {
                    pData[playerid][P_Aux] = 0;
                    ShowTextDrawDialog(playerid, 10, 0, 0);
                }
                else // If he was editing X, move him back to select menu
                {
                    ShowTextDrawDialog(playerid, 9);
                }
            }
        }
        
        case 1585: // Change textdraw's alignment
        {
            if(response)
            {
                if(listitem == 3) // Remover alinhamento (tipo 0)
                {
                    tData[pData[playerid][P_CurrentTextdraw]][T_Alignment] = 0;
                    new string[128];
                    format(string, sizeof(string), "Alinhamento da Textdraw #%d removido.", pData[playerid][P_CurrentTextdraw]);
                    SendClientMessage(playerid, MSG_COLOR, string);
                }
                else
                {
                    tData[pData[playerid][P_CurrentTextdraw]][T_Alignment] = listitem+1;
                    new string[128];
                    format(string, sizeof(string), "Alinhamento da Textdraw #%d alterado para %d.", pData[playerid][P_CurrentTextdraw], listitem+1);
                    SendClientMessage(playerid, MSG_COLOR, string);
                }
                	                UpdateTextdraw(pData[playerid][P_CurrentTextdraw]);
	                SaveTDData(pData[playerid][P_CurrentTextdraw], "T_Alignment");
	                if(pData[playerid][P_ClickAreaOverlayEnabled]) RebuildClickAreaOverlay(playerid);
	                ShowTextDrawDialog(playerid, 5);
            }
            else
            {
                ShowTextDrawDialog(playerid, 5);
            }
        }
        
        case 1586: // Change textdraw's proportionality
        {
            if(response)
            {
                tData[pData[playerid][P_CurrentTextdraw]][T_Proportional] = listitem;
                UpdateTextdraw(pData[playerid][P_CurrentTextdraw]);
                SaveTDData(pData[playerid][P_CurrentTextdraw], "T_Proportional");

                				new string[128];
	                format(string, sizeof(string), "Proporcionalidade da Textdraw #%d alterada para %d.", pData[playerid][P_CurrentTextdraw], listitem);
	                SendClientMessage(playerid, MSG_COLOR, string);

                ShowTextDrawDialog(playerid, 5);
            }
            else
            {
                ShowTextDrawDialog(playerid, 5);
            }
        }
        
        case 1587: // Change color
        {
            if(response)
            {
                switch(listitem)
                {
                    case 0: // Write hex
                    {
                        ShowTextDrawDialog(playerid, 14);
                    }
                    case 1: // Color combinator
                    {
                        ShowTextDrawDialog(playerid, 15, 0, 0);
                    }
                    case 2: // Premade color
                    {
                        ShowTextDrawDialog(playerid, 16);
                    }
                    case 3: // Search
                    {
                        ShowTextDrawDialog(playerid, 40);
                    }
                    case 4: // Group
                    {
                        ShowTextDrawDialog(playerid, 41);
                    }
                    case 5: // Sort
                    {
                        ShowTextDrawDialog(playerid, 42);
                    }
                    case 6: // Recents
                    {
                        ShowTextDrawDialog(playerid, 43);
                    }
                    case 7: // Alterar transparencia (alpha)
                    {
                        ShowTextDrawDialog(playerid, 45);
                    }
                }
            }
            else
            {
                if(pData[playerid][P_ColorEdition] == COLOR_TEXT) 			ShowTextDrawDialog(playerid, 5);
                else if(pData[playerid][P_ColorEdition] == COLOR_OUTLINE)   ShowTextDrawDialog(playerid, 20);
                else if(pData[playerid][P_ColorEdition] == COLOR_BOX)		ShowTextDrawDialog(playerid, 24);
            }
        }
        
        case 1588: // Textdraw's color: custom hex
        {
        	if(response)
            {
                new red[3], green[3], blue[3], alpha[3];
                
                if(inputtext[0] == '0' && inputtext[1] == 'x') // He's using 0xFFFFFF format
                {
                    if(strlen(inputtext) != 8 && strlen(inputtext) != 10) return ShowTextDrawDialog(playerid, 14, 1);
                    else
                    {
	                    format(red, sizeof(red), "%c%c", inputtext[2], inputtext[3]);
	                    format(green, sizeof(green), "%c%c", inputtext[4], inputtext[5]);
	                    format(blue, sizeof(blue), "%c%c", inputtext[6], inputtext[7]);
	                    if(inputtext[8] != '\0')
	                        format(alpha, sizeof(alpha), "%c%c", inputtext[8], inputtext[9]);
						else
						    alpha = "FF";
					}
                }
                else if(inputtext[0] == '#') // He's using #FFFFFF format
                {
                    if(strlen(inputtext) != 7 && strlen(inputtext) != 9) return ShowTextDrawDialog(playerid, 14, 1);
                    else
                    {
	                    format(red, sizeof(red), "%c%c", inputtext[1], inputtext[2]);
	                    format(green, sizeof(green), "%c%c", inputtext[3], inputtext[4]);
	                    format(blue, sizeof(blue), "%c%c", inputtext[5], inputtext[6]);
	                    if(inputtext[7] != '\0')
	                        format(alpha, sizeof(alpha), "%c%c", inputtext[7], inputtext[8]);
						else
						    alpha = "FF";
					}
                }
                else // He's using FFFFFF format
                {
                    if(strlen(inputtext) != 6 && strlen(inputtext) != 8) return ShowTextDrawDialog(playerid, 14, 1);
                    else
                    {
	                    format(red, sizeof(red), "%c%c", inputtext[0], inputtext[1]);
	                    format(green, sizeof(green), "%c%c", inputtext[2], inputtext[3]);
	                    format(blue, sizeof(blue), "%c%c", inputtext[4], inputtext[5]);
	                    if(inputtext[6] != '\0')
	                        format(alpha, sizeof(alpha), "%c%c", inputtext[6], inputtext[7]);
						else
						    alpha = "FF";
					}
                }
                // We got the color
                if(pData[playerid][P_ColorEdition] == COLOR_TEXT)
                	tData[pData[playerid][P_CurrentTextdraw]][T_Color] = RGB(HexToInt(red), HexToInt(green), HexToInt(blue), HexToInt(alpha));
				else if(pData[playerid][P_ColorEdition] == COLOR_OUTLINE)
				    tData[pData[playerid][P_CurrentTextdraw]][T_BackColor] = RGB(HexToInt(red), HexToInt(green), HexToInt(blue), HexToInt(alpha));
                else if(pData[playerid][P_ColorEdition] == COLOR_BOX)
				    tData[pData[playerid][P_CurrentTextdraw]][T_BoxColor] = RGB(HexToInt(red), HexToInt(green), HexToInt(blue), HexToInt(alpha));
                UpdateTextdraw(pData[playerid][P_CurrentTextdraw]);
                SaveTDData(pData[playerid][P_CurrentTextdraw], "T_Color");
                SaveTDData(pData[playerid][P_CurrentTextdraw], "T_BackColor");
                SaveTDData(pData[playerid][P_CurrentTextdraw], "T_BoxColor");
                
                new string[128];
                format(string, sizeof(string), "A cor da Textdraw #%d foi alterada.", pData[playerid][P_CurrentTextdraw]);
                SendClientMessage(playerid, MSG_COLOR, string);

                if(pData[playerid][P_ColorEdition] == COLOR_TEXT) 			ShowTextDrawDialog(playerid, 5);
                else if(pData[playerid][P_ColorEdition] == COLOR_OUTLINE)   ShowTextDrawDialog(playerid, 20);
                else if(pData[playerid][P_ColorEdition] == COLOR_BOX)		ShowTextDrawDialog(playerid, 24);
            }
            else
            {
                ShowTextDrawDialog(playerid, 13);
            }
		}
		case 1589: // Textdraw's color: Color combinator
        {
            if(response)
            {
                if(!IsNumeric2(inputtext)) ShowTextDrawDialog(playerid, 15, pData[playerid][P_Aux], 2);
                else if(strval(inputtext) < 0 || strval(inputtext) > 255) ShowTextDrawDialog(playerid, 15, pData[playerid][P_Aux], 1);
                else
                {
                    pData[playerid][P_Color][pData[playerid][P_Aux]] = strval(inputtext);
             	    
                    if(pData[playerid][P_Aux] == 3) // He finished editing alpha, he has the rest.
                    {
                        // We got the color
                        if(pData[playerid][P_ColorEdition] == COLOR_TEXT)
		                	tData[pData[playerid][P_CurrentTextdraw]][T_Color] = RGB(pData[playerid][P_Color][0], pData[playerid][P_Color][1], \
																				 pData[playerid][P_Color][2], pData[playerid][P_Color][3] );
						else if(pData[playerid][P_ColorEdition] == COLOR_OUTLINE)
						    tData[pData[playerid][P_CurrentTextdraw]][T_BackColor] = RGB(pData[playerid][P_Color][0], pData[playerid][P_Color][1], \
																				 pData[playerid][P_Color][2], pData[playerid][P_Color][3] );
		                else if(pData[playerid][P_ColorEdition] == COLOR_BOX)
						    tData[pData[playerid][P_CurrentTextdraw]][T_BoxColor] = RGB(pData[playerid][P_Color][0], pData[playerid][P_Color][1], \
																				 pData[playerid][P_Color][2], pData[playerid][P_Color][3] );
		                UpdateTextdraw(pData[playerid][P_CurrentTextdraw]);
		                SaveTDData(pData[playerid][P_CurrentTextdraw], "T_Color");
		                SaveTDData(pData[playerid][P_CurrentTextdraw], "T_BackColor");
		                SaveTDData(pData[playerid][P_CurrentTextdraw], "T_BoxColor");

		                			        new string[128];
			        format(string, sizeof(string), "A cor da Textdraw #%d foi alterada.", pData[playerid][P_CurrentTextdraw]);
			        SendClientMessage(playerid, MSG_COLOR, string);

		                if(pData[playerid][P_ColorEdition] == COLOR_TEXT) 			ShowTextDrawDialog(playerid, 5);
               			else if(pData[playerid][P_ColorEdition] == COLOR_OUTLINE)   ShowTextDrawDialog(playerid, 20);
               			else if(pData[playerid][P_ColorEdition] == COLOR_BOX)		ShowTextDrawDialog(playerid, 24);
                    }
                    else
                    {
                        pData[playerid][P_Aux] += 1;
	                    ShowTextDrawDialog(playerid, 15, pData[playerid][P_Aux], 0);
					}
                }
            }
            else
            {
                if(pData[playerid][P_Aux] >= 1) // If he is editing alpha, blue, etc.
                {
                    pData[playerid][P_Aux] -= 1;
                    ShowTextDrawDialog(playerid, 15, pData[playerid][P_Aux], 0);
                }
                else // If he was editing red, move him back to select color menu.
                {
                    ShowTextDrawDialog(playerid, 13);
                }
            }
        }
        
        case 1590: // Textdraw's color: premade colors
        {
            if(response)
            {
                new indices[sizeof(HTML_COLORS)];
                new count = BuildFilteredSortedIndices(playerid, indices, sizeof(indices));
                if(count <= 0)
                {
                	ShowTextDrawDialog(playerid, 16);
                	return true;
                }
                new start = pData[playerid][P_ColorPageStart];
                if(start < 0) start = 0;
                if(start >= count) {
                	if(count == 0) start = 0; else start = (count - 1) - ((count - 1) % COLOR_PRESET_PAGE_SIZE);
                	pData[playerid][P_ColorPageStart] = start;
                }
                new itemsOnPage = COLOR_PRESET_PAGE_SIZE;
                if(count - start < itemsOnPage) itemsOnPage = count - start;
                new bool:hasPrev = (start > 0);
                new bool:hasNext = (start + itemsOnPage < count);

                // Navigate pages
                if(hasPrev && listitem == 0) {
                    pData[playerid][P_ColorPageStart] = start - COLOR_PRESET_PAGE_SIZE;
                    ShowTextDrawDialog(playerid, 16);
                    return true;
                }
                new idxBase = hasPrev ? 1 : 0;
                if(hasNext && listitem == idxBase + itemsOnPage) {
                    pData[playerid][P_ColorPageStart] = start + COLOR_PRESET_PAGE_SIZE;
                    ShowTextDrawDialog(playerid, 16);
                    return true;
                }

                // Select color from the current page
                new relative = listitem - idxBase;
                if(relative < 0 || relative >= itemsOnPage) {
                    ShowTextDrawDialog(playerid, 16);
                    return true;
                }
                new index = indices[start + relative];
                // Apply selected color immediately with full opacity (no transparency prompt)
                new alpha = 255;
                if(index >= 0 && index < sizeof(HTML_COLORS))
                {
                    new hexstr[8];
                    format(hexstr, sizeof(hexstr), "%s", HTML_COLORS[index][HTMLColorHex]); // #RRGGBB
                    new rhex[3], ghex[3], bhex[3];
                    format(rhex, sizeof(rhex), "%c%c", hexstr[1], hexstr[2]);
                    format(ghex, sizeof(ghex), "%c%c", hexstr[3], hexstr[4]);
                    format(bhex, sizeof(bhex), "%c%c", hexstr[5], hexstr[6]);
                    new col = RGB(HexToInt(rhex), HexToInt(ghex), HexToInt(bhex), alpha);
                    if(pData[playerid][P_ColorEdition] == COLOR_TEXT)
                        tData[pData[playerid][P_CurrentTextdraw]][T_Color] = col;
                    else if(pData[playerid][P_ColorEdition] == COLOR_OUTLINE)
                        tData[pData[playerid][P_CurrentTextdraw]][T_BackColor] = col;
                    else if(pData[playerid][P_ColorEdition] == COLOR_BOX)
                        tData[pData[playerid][P_CurrentTextdraw]][T_BoxColor] = col;
                    UpdateTextdraw(pData[playerid][P_CurrentTextdraw]);
                    SaveTDData(pData[playerid][P_CurrentTextdraw], "T_Color");
                    SaveTDData(pData[playerid][P_CurrentTextdraw], "T_BackColor");
                    SaveTDData(pData[playerid][P_CurrentTextdraw], "T_BoxColor");
                    // Push to recents (front)
                    for(new k = 9; k > 0; k--) pData[playerid][P_RecentColors][k] = pData[playerid][P_RecentColors][k-1];
                    pData[playerid][P_RecentColors][0] = index;
                    if(pData[playerid][P_RecentCount] < 10) pData[playerid][P_RecentCount]++;
                    new string[128];
                    format(string, sizeof(string), "A cor da Textdraw #%d foi alterada.", pData[playerid][P_CurrentTextdraw]);
                    SendClientMessage(playerid, MSG_COLOR, string);
                }
                // Back to appropriate menu
                if(pData[playerid][P_ColorEdition] == COLOR_TEXT) ShowTextDrawDialog(playerid, 5);
                else if(pData[playerid][P_ColorEdition] == COLOR_OUTLINE) ShowTextDrawDialog(playerid, 20);
                else if(pData[playerid][P_ColorEdition] == COLOR_BOX) ShowTextDrawDialog(playerid, 24);
            }
            else
            {
                ShowTextDrawDialog(playerid, 13);
            }
        }
        
        case 1591: // Change textdraw's font
        {
            if(response)
            {
                tData[pData[playerid][P_CurrentTextdraw]][T_Font] = listitem;
                UpdateTextdraw(pData[playerid][P_CurrentTextdraw]);
                SaveTDData(pData[playerid][P_CurrentTextdraw], "T_Font");

                new string[128];
                format(string, sizeof(string), "Fonte da Textdraw #%d alterada para %d.", pData[playerid][P_CurrentTextdraw], listitem);
                SendClientMessage(playerid, MSG_COLOR, string);
                if(listitem < 5)
				{
					if(GetPVarInt(playerid, "Use2DTD") == 1)
					{
						DeletePVar(playerid, "Use2DTD");
					}
				}
                if(listitem == 4)
                {
                    SendClientMessage(playerid,-1, "Para usar a fonte 4, ative a caixa.");
                    SendClientMessage(playerid,-1, "Altere o tamanho da caixa para mudar o tamanho da TD.");
                    SendClientMessage(playerid,-1, "Função adicionada por irinel1996.");
				}
                if(listitem == 5)
                {
                    SetPVarInt(playerid, "Use2DTD", 1);
                    SendClientMessage(playerid,-1, "Add by adri1.");
                    SendClientMessage(playerid,-1, "Important: Use Box!");
				}
                ShowTextDrawDialog(playerid, 5);
            }
            else
            {
                ShowTextDrawDialog(playerid, 5);
            }
        }
        
        case 1592: // Change textdraw's letter size: exact or move
        {
            if(response)
            {
                switch(listitem)
                {
                    case 0: // Exact size
                    {
                        pData[playerid][P_Aux] = 0;
                        ShowTextDrawDialog(playerid, 19, 0, 0);
                    }
                    case 1: // Resize it
                    {
                        new string[512];
                        string = "~n~~n~~n~~n~~n~~n~~n~~n~~w~";
                        if(!IsPlayerInAnyVehicle(playerid))	format(string, sizeof(string), "%s~k~~GO_FORWARD~, ~k~~GO_BACK~, ~k~~GO_LEFT~, ~k~~GO_RIGHT~~n~", string);
						else								format(string, sizeof(string), "%s~k~~VEHICLE_STEERUP~, ~k~~VEHICLE_STEERDOWN~, ~k~~VEHICLE_STEERLEFT~, ~k~~VEHICLE_STEERRIGHT~~n~", string);
						format(string, sizeof(string), "%sand ~k~~PED_SPRINT~ to resize. ", string);
						if(!IsPlayerInAnyVehicle(playerid))	format(string, sizeof(string), "%s~k~~VEHICLE_ENTER_EXIT~", string);
						else								format(string, sizeof(string), "%s~k~~VEHICLE_FIREWEAPON_ALT~", string);
						format(string, sizeof(string), "%s to finish.~n~", string);

						GameTextForPlayer(playerid, string, 9999999, 3);
						SendClientMessage(playerid, MSG_COLOR, "Use [cima], [baixo], [esquerda] e [direita] para redimensionar a textdraw. [sprint] acelera e [entrar veículo] finaliza.");

						TogglePlayerControllable(playerid, 0);
						pData[playerid][P_KeyEdition] = EDIT_SIZE;
						SetTimerEx("KeyEdit", 200, 0, "i", playerid);
						if(pData[playerid][P_ClickAreaOverlayEnabled]) RebuildClickAreaOverlay(playerid);
                    }
                }
            }
            else
            {
                ShowTextDrawDialog(playerid, 5);
            }
        }
        
        case 1593: // Change letter size manually
        {
            if(response)
            {
                if(!IsNumeric2(inputtext)) ShowTextDrawDialog(playerid, 19, pData[playerid][P_Aux], 1);
                else
                {
                    if(pData[playerid][P_Aux] == 0) // If he edited X
                    {
                        tData[pData[playerid][P_CurrentTextdraw]][T_XSize] = floatstr(inputtext);
                        UpdateTextdraw(pData[playerid][P_CurrentTextdraw]);
                        SaveTDData(pData[playerid][P_CurrentTextdraw], "T_XSize");
                        ShowTextDrawDialog(playerid, 19, 1, 0);
                    }
                    else if(pData[playerid][P_Aux] == 1) // If he edited Y
                    {
                        tData[pData[playerid][P_CurrentTextdraw]][T_YSize] = floatstr(inputtext);
                        UpdateTextdraw(pData[playerid][P_CurrentTextdraw]);
                        SaveTDData(pData[playerid][P_CurrentTextdraw], "T_YSize");
                        ShowTextDrawDialog(playerid, 5);

						SendClientMessage(playerid, MSG_COLOR, "Textdraw redimensionada com sucesso.");
                    }
                }
            }
            else
            {
                if(pData[playerid][P_Aux] == 1) // If he is editing Y, move him to X.
                {
                    pData[playerid][P_Aux] = 0;
                    ShowTextDrawDialog(playerid, 19, 0, 0);
                }
                else // If he was editing X, move him back to select menu
                {
                    ShowTextDrawDialog(playerid, 18);
                }
            }
        }
        
        case 1594: // main outline menu
        {
            if(response)
            {
				switch(listitem)
				{
				    case 0: // Toggle outline
				    {
				        if(tData[pData[playerid][P_CurrentTextdraw]][T_Outline])	tData[pData[playerid][P_CurrentTextdraw]][T_Outline] = 0;
				        else                                                        tData[pData[playerid][P_CurrentTextdraw]][T_Outline] = 1;
				        UpdateTextdraw(pData[playerid][P_CurrentTextdraw]);
				        SaveTDData(pData[playerid][P_CurrentTextdraw], "T_Outline");
				        ShowTextDrawDialog(playerid, 20);
				        
				        SendClientMessage(playerid, MSG_COLOR, "Contorno da textdraw alternado.");
				    }
					case 1: // Change shadow
					{
                        ShowTextDrawDialog(playerid, 21);
					}
					case 2: // Change color
					{
		                pData[playerid][P_ColorEdition] = COLOR_OUTLINE;
                        ShowTextDrawDialog(playerid, 13);
					}
					case 3: // Finish
	                {
	                    SendClientMessage(playerid, MSG_COLOR, "Edição de contorno concluída.");
	                    ShowTextDrawDialog(playerid, 5);
	                }
				}
            }
            else
            {
                ShowTextDrawDialog(playerid, 5);
            }
        }
        
        case 1595: // Outline shadow
        {
            if(response)
            {
                if(listitem == 6) // selected custom
                {
                    ShowTextDrawDialog(playerid, 22);
                }
                else
                {
                    tData[pData[playerid][P_CurrentTextdraw]][T_Shadow] = listitem;
                    UpdateTextdraw(pData[playerid][P_CurrentTextdraw]);
                    SaveTDData(pData[playerid][P_CurrentTextdraw], "T_Shadow");
                    ShowTextDrawDialog(playerid, 20);

					new string[128];
	                format(string, sizeof(string), "Sombra do contorno da Textdraw #%d alterada para %d.", pData[playerid][P_CurrentTextdraw], listitem);
	                SendClientMessage(playerid, MSG_COLOR, string);
                }
            }
            else
            {
                ShowTextDrawDialog(playerid, 20);
            }
        }
        
        case 1596: // outline shaow customized
        {
            if(response)
            {
                if(!IsNumeric2(inputtext)) ShowTextDrawDialog(playerid, 22, 1);
                else
                {
                    tData[pData[playerid][P_CurrentTextdraw]][T_Shadow] = strval(inputtext);
                    UpdateTextdraw(pData[playerid][P_CurrentTextdraw]);
                    SaveTDData(pData[playerid][P_CurrentTextdraw], "T_Shadow");
                    ShowTextDrawDialog(playerid, 20);

					new string[128];
	                format(string, sizeof(string), "Sombra do contorno da Textdraw #%d alterada para %d.", pData[playerid][P_CurrentTextdraw], strval(inputtext));
	                SendClientMessage(playerid, MSG_COLOR, string);
                }
            }
            else
            {
                ShowTextDrawDialog(playerid, 21);
            }
        }
        
        case 1597: // Box on - off
        {
            if(response)
            {
                switch(listitem)
                {
                    case 0: // Turned box on
                    {
                        tData[pData[playerid][P_CurrentTextdraw]][T_UseBox] = 1;
						UpdateTextdraw(pData[playerid][P_CurrentTextdraw]);
						SaveTDData(pData[playerid][P_CurrentTextdraw], "T_UseBox");

						SendClientMessage(playerid, MSG_COLOR, "Caixa da textdraw ativada. Prosseguindo com a edição...");

						ShowTextDrawDialog(playerid, 24);
                    }
                    case 1: // He disabled it, nothing more to edit.
                    {
						tData[pData[playerid][P_CurrentTextdraw]][T_UseBox] = 0;
						UpdateTextdraw(pData[playerid][P_CurrentTextdraw]);
											SaveTDData(pData[playerid][P_CurrentTextdraw], "T_UseBox");
					
					SendClientMessage(playerid, MSG_COLOR, "Caixa da textdraw desativada.");
					ShowTextDrawDialog(playerid, 5);
                    }
                }
            }
            else
            {
                ShowTextDrawDialog(playerid, 5);
            }
        }
        
        case 1598: // Box main menu
        {
            if(response)
            {
                switch(listitem)
                {
                    case 0: // Turned box off
                    {
                        tData[pData[playerid][P_CurrentTextdraw]][T_UseBox] = 0;
						UpdateTextdraw(pData[playerid][P_CurrentTextdraw]);
											SaveTDData(pData[playerid][P_CurrentTextdraw], "T_UseBox");

					SendClientMessage(playerid, MSG_COLOR, "Caixa da textdraw desativada.");

					ShowTextDrawDialog(playerid, 23);
                    }
                    case 1: // box size
                    {
                        new string[512];
                        string = "~n~~n~~n~~n~~n~~n~~n~~n~~w~";
                        if(!IsPlayerInAnyVehicle(playerid))
                            format(string, sizeof(string), "%s~k~~GO_FORWARD~, ~k~~GO_BACK~, ~k~~GO_LEFT~, ~k~~GO_RIGHT~~n~", string);
                        else
                            format(string, sizeof(string), "%s~k~~VEHICLE_STEERUP~, ~k~~VEHICLE_STEERDOWN~, ~k~~VEHICLE_STEERLEFT~, ~k~~VEHICLE_STEERRIGHT~~n~", string);
                        format(string, sizeof(string), "%sand ~k~~PED_SPRINT~ to resize. ", string);
                        if(!IsPlayerInAnyVehicle(playerid))
                            format(string, sizeof(string), "%s~k~~VEHICLE_ENTER_EXIT~", string);
                        else
                            format(string, sizeof(string), "%s~k~~VEHICLE_FIREWEAPON_ALT~", string);
                        format(string, sizeof(string), "%s to finish.~n~", string);

                        GameTextForPlayer(playerid, string, 9999999, 3);
                        SendClientMessage(playerid, MSG_COLOR, "Use [cima], [baixo], [esquerda] e [direita] para redimensionar a caixa. [sprint] acelera e [entrar veiculo] finaliza.");

                        TogglePlayerControllable(playerid, 0);
                        pData[playerid][P_KeyEdition] = EDIT_BOX;
                        if(pData[playerid][P_ClickAreaOverlayEnabled]) RebuildClickAreaOverlay(playerid);
                        SetTimerEx("KeyEdit", 200, 0, "i", playerid);
                    }
                    case 2: // box color
                    {
                        pData[playerid][P_ColorEdition] = COLOR_BOX;
                        ShowTextDrawDialog(playerid, 13);
                    }
                }
            }
            else
            {
                ShowTextDrawDialog(playerid, 5);
            }
        }
        case 1606: // Change textdraw's selectable
        {
            if(response)
            {
                tData[pData[playerid][P_CurrentTextdraw]][T_Selectable] = 1;
                UpdateTextdraw(pData[playerid][P_CurrentTextdraw]);
                SaveTDData(pData[playerid][P_CurrentTextdraw], "T_Selectable");

                new string[128];
                format(string, sizeof(string), "Seleção da Textdraw #%d ativada.", pData[playerid][P_CurrentTextdraw]);
                SendClientMessage(playerid, MSG_COLOR, string);
                ShowTextDrawDialog(playerid, 5);
            }
            else
            {
                tData[pData[playerid][P_CurrentTextdraw]][T_Selectable] = 0;
                UpdateTextdraw(pData[playerid][P_CurrentTextdraw]);
                SaveTDData(pData[playerid][P_CurrentTextdraw], "T_Selectable");

                new string[128];
                format(string, sizeof(string), "Seleção da Textdraw #%d desativada.", pData[playerid][P_CurrentTextdraw]);
                SendClientMessage(playerid, MSG_COLOR, string);
                ShowTextDrawDialog(playerid, 5);
            }
        }
        case 1607: // Preview model
        {
      //  Model Index\nRot X\nRot Y\nRot Z\nZoom
            if(response)
            {
                if(listitem == 0)
                {
                    ShowTextDrawDialog(playerid, 34);
				}
                if(listitem == 1)
                {
                    ShowTextDrawDialog(playerid, 35);
				}
				if(listitem == 2)
                {
                    ShowTextDrawDialog(playerid, 36);
				}
				if(listitem == 3)
                {
                    ShowTextDrawDialog(playerid, 37);
				}
				if(listitem == 4)
                {
                    ShowTextDrawDialog(playerid, 38);
				}
            }
            else
            {
                ShowTextDrawDialog(playerid, 5);
            }
        }
        case 1608: // Model Index
        {
			if(response)
			{
				if(!IsNumeric2(inputtext)) return ShowTextDrawDialog(playerid, 33);
                tData[pData[playerid][P_CurrentTextdraw]][T_PreviewModel] = strval(inputtext);
                UpdateTextdraw(pData[playerid][P_CurrentTextdraw]);
                SaveTDData(pData[playerid][P_CurrentTextdraw], "T_PreviewModel");

                new string[128];
                format(string, sizeof(string), "Preview Model da Textdraw #%d alterado para \"%d\".", pData[playerid][P_CurrentTextdraw], strval(inputtext));
                SendClientMessage(playerid, MSG_COLOR, string);
                ShowTextDrawDialog(playerid, 33);
			}
			else
			{
			    ShowTextDrawDialog(playerid, 33);
			}
		}
        case 1609: // Rot X
        {
			if(response)
			{
				if(!IsNumeric2(inputtext)) return ShowTextDrawDialog(playerid, 33);
                tData[pData[playerid][P_CurrentTextdraw]][PMRotX] = floatstr(inputtext);
                UpdateTextdraw(pData[playerid][P_CurrentTextdraw]);
                SaveTDData(pData[playerid][P_CurrentTextdraw], "PMRotX");

                new string[128];
                format(string, sizeof(string), "Preview Model RX da Textdraw #%d alterado para \"%f\".", pData[playerid][P_CurrentTextdraw], floatstr(inputtext));
                SendClientMessage(playerid, MSG_COLOR, string);
                ShowTextDrawDialog(playerid, 33);
			}
			else
			{
			    ShowTextDrawDialog(playerid, 33);
			}
		}
        case 1610: // Rot Y
        {
			if(response)
			{
				if(!IsNumeric2(inputtext)) return ShowTextDrawDialog(playerid, 33);
                tData[pData[playerid][P_CurrentTextdraw]][PMRotY] = floatstr(inputtext);
                UpdateTextdraw(pData[playerid][P_CurrentTextdraw]);
                SaveTDData(pData[playerid][P_CurrentTextdraw], "PMRotY");

                new string[128];
                format(string, sizeof(string), "Preview Model RY da Textdraw #%d alterado para \"%f\".", pData[playerid][P_CurrentTextdraw], floatstr(inputtext));
                SendClientMessage(playerid, MSG_COLOR, string);
                ShowTextDrawDialog(playerid, 33);
			}
			else
			{
			    ShowTextDrawDialog(playerid, 33);
			}
		}
        case 1611: // Rot Z
        {
			if(response)
			{
				if(!IsNumeric2(inputtext)) return ShowTextDrawDialog(playerid, 33);
                tData[pData[playerid][P_CurrentTextdraw]][PMRotZ] = floatstr(inputtext);
                UpdateTextdraw(pData[playerid][P_CurrentTextdraw]);
                SaveTDData(pData[playerid][P_CurrentTextdraw], "PMRotZ");

                new string[128];
                format(string, sizeof(string), "Preview Model RZ da Textdraw #%d alterado para \"%f\".", pData[playerid][P_CurrentTextdraw], floatstr(inputtext));
                SendClientMessage(playerid, MSG_COLOR, string);
                ShowTextDrawDialog(playerid, 33);
			}
			else
			{
			    ShowTextDrawDialog(playerid, 33);
			}
		}
        case 1612: // Zoom
        {
			if(response)
			{
				if(!IsNumeric2(inputtext)) return ShowTextDrawDialog(playerid, 33);
                tData[pData[playerid][P_CurrentTextdraw]][PMZoom] = floatstr(inputtext);
                UpdateTextdraw(pData[playerid][P_CurrentTextdraw]);
                SaveTDData(pData[playerid][P_CurrentTextdraw], "PMZoom");

                new string[128];
                format(string, sizeof(string), "Zoom do Preview Model da Textdraw #%d alterado para \"%f\".", pData[playerid][P_CurrentTextdraw], floatstr(inputtext));
                SendClientMessage(playerid, MSG_COLOR, string);
                ShowTextDrawDialog(playerid, 33);
			}
			else
			{
			    ShowTextDrawDialog(playerid, 33);
			}
		}
        case 1599: // Export menu
        {
            if(response)
            {
                switch(listitem)
                {
                    case 0: // classic mode
                    {
                        ExportProject(playerid, 0);
                    }
                    case 1: // self-working fs
                    {
						ShowTextDrawDialog(playerid, 26);
                    }
                    case 2: // PlayerTextDraw [ADD BY ADRI1]
                    {
                        ExportProject(playerid, 7);
                    }
                    case 3: // Mixed mode (By ForT)
                    {
                        ExportProject(playerid, 8);
                    }
                }
            }
            else
            {
                ShowTextDrawDialog(playerid, 4);
            }
        }
        
        case 1600: // Export to self working filterscript
        {
            if(response)
            {
                switch(listitem)
                {
                    case 0: // Show all the time.
                    {
                        ExportProject(playerid, 1);
                    }
                    case 1: // Show on class selection.
                    {
                        ExportProject(playerid, 2);
                    }
                    case 2: // Show while in vehicle
                    {
                        ExportProject(playerid, 3);
                    }
                    case 3: // Show with command
                    {
                        ShowTextDrawDialog(playerid, 27);
                    }
                    case 4: // Show automatly repeteadly after some time
                    {
                        ShowTextDrawDialog(playerid, 29);
                    }
                    case 5: // Show after player killed someone
                    {
                        ShowTextDrawDialog(playerid, 31);
                    }
                }
            }
            else
            {
                ShowTextDrawDialog(playerid, 25);
            }
        }

		case 1601: // Write command for export
		{
		    if(response)
		    {
		        if(!strlen(inputtext)) ShowTextDrawDialog(playerid, 27);
		        else
		        {
		            if(inputtext[0] != '/')
		                format(pData[playerid][P_ExpCommand], 128, "/%s", inputtext);
		            else
		                format(pData[playerid][P_ExpCommand], 128, "%s", inputtext);
		                
					ShowTextDrawDialog(playerid, 28);
		        }
		    }
		    else
		    {
		        ShowTextDrawDialog(playerid, 26);
		    }
		}
		
		case 1602: // Time after command for export
		{
		    if(response)
		    {
				if(!IsNumeric2(inputtext)) ShowTextDrawDialog(playerid, 28);
				else if(strval(inputtext) < 0) ShowTextDrawDialog(playerid, 28);
				else
				{
				    pData[playerid][P_Aux] = strval(inputtext);
				    ExportProject(playerid, 4);
				}
		    }
		    else
		    {
		        ShowTextDrawDialog(playerid, 27);
		    }
		}
		
		case 1603: // Write time in secs to appear for export
		{
		    if(response)
		    {
		        if(!IsNumeric2(inputtext)) ShowTextDrawDialog(playerid, 29);
				else if(strval(inputtext) < 0) ShowTextDrawDialog(playerid, 29);
				else
				{
				    pData[playerid][P_Aux] = strval(inputtext);
				    ShowTextDrawDialog(playerid, 30);
				}
		    }
		    else
		    {
		        ShowTextDrawDialog(playerid, 26);
		    }
		}
		case 1604: // Time after appeared to dissapear for export
		{
		    if(response)
		    {
				if(!IsNumeric2(inputtext)) ShowTextDrawDialog(playerid, 30);
				else if(strval(inputtext) < 0) ShowTextDrawDialog(playerid, 30);
				else
				{
				    pData[playerid][P_Aux2] = strval(inputtext);
				    ExportProject(playerid, 5);
				}
		    }
		    else
		    {
		        ShowTextDrawDialog(playerid, 29);
		    }
		}
		
		case 1605: // Time after appeared to dissapear when kill for export
		{
		    if(response)
		    {
				if(!IsNumeric2(inputtext)) ShowTextDrawDialog(playerid, 31);
				else if(strval(inputtext) < 0) ShowTextDrawDialog(playerid, 31);
				else
				{
				    pData[playerid][P_Aux] = strval(inputtext);
				    ExportProject(playerid, 6);
				}
		    }
		    else
		    {
		        ShowTextDrawDialog(playerid, 26);
		    }
		}

        case 1613: // Change textdraw's mode
        {
            if(response)
            {
                tData[pData[playerid][P_CurrentTextdraw]][T_Mode] = 0;
                UpdateTextdraw(pData[playerid][P_CurrentTextdraw]);
                SaveTDData(pData[playerid][P_CurrentTextdraw], "T_Mode");

                new string[128];
                format(string, sizeof(string), "Modo da Textdraw #%d: GLOBAL.", pData[playerid][P_CurrentTextdraw]);
                SendClientMessage(playerid, MSG_COLOR, string);
                ShowTextDrawDialog(playerid, 5);
            }
            else
            {
                tData[pData[playerid][P_CurrentTextdraw]][T_Mode] = 1;
                UpdateTextdraw(pData[playerid][P_CurrentTextdraw]);
                SaveTDData(pData[playerid][P_CurrentTextdraw], "T_Mode");

                new string[128];
                format(string, sizeof(string), "Modo da Textdraw #%d: PLAYER", pData[playerid][P_CurrentTextdraw]);
                SendClientMessage(playerid, MSG_COLOR, string);
                ShowTextDrawDialog(playerid, 5);
            }
        }
        case 39:
        {
            new info[175];
            format(info, sizeof(info), "Modo da Textdraw. O modo atual é: %s\n",tData[pData[playerid][P_CurrentTextdraw]][T_Mode] == 0 ? ("Global") : ("Player"));

            ShowPlayerDialog(playerid, dialogid+1574, DIALOG_STYLE_MSGBOX, CreateDialogTitle(playerid, "Modo da Textdraw"), info, "Global", "Player");
            return true;
        }
        
        case 2000: // Box size X input
        {
            if(response)
            {
                new Float:value;
                if(!IsNumeric2(inputtext))
                {
                    SendClientMessage(playerid, MSG_COLOR, "ERRO: Digite apenas numeros!");
                    new string[128];
                    format(string, sizeof(string), "Digite a largura da area de clique (atual: %.2f):", tData[pData[playerid][P_CurrentTextdraw]][T_TextSizeX]);
                    ShowPlayerDialog(playerid, 2000, DIALOG_STYLE_INPUT, "Area de Clique - Largura", string, "Proximo", "Cancelar");
                    return 1;
                }
                value = floatstr(inputtext);
                
                tData[pData[playerid][P_CurrentTextdraw]][T_TextSizeX] = value;
                UpdateTextdraw(pData[playerid][P_CurrentTextdraw]);
                SaveTDData(pData[playerid][P_CurrentTextdraw], "T_TextSizeX");
                if(pData[playerid][P_ClickAreaOverlayEnabled]) RebuildClickAreaOverlay(playerid);
                
                // Show Y input dialog
                new string[128];
                format(string, sizeof(string), "Digite a altura da area de clique (atual: %.2f):", tData[pData[playerid][P_CurrentTextdraw]][T_TextSizeY]);
                ShowPlayerDialog(playerid, 2001, DIALOG_STYLE_INPUT, "Area de Clique - Altura", string, "Concluir", "Cancelar");
            }
            else
            {
                pData[playerid][P_KeyEdition] = EDIT_NONE;
                ShowTextDrawDialog(playerid, 5);
            }
        }
        
        case 2001: // Box size Y input
        {
            if(response)
            {
                new Float:value;
                if(!IsNumeric2(inputtext))
                {
                    SendClientMessage(playerid, MSG_COLOR, "ERRO: Digite apenas numeros!");
                    new string[128];
                    format(string, sizeof(string), "Digite a altura da area de clique (atual: %.2f):", tData[pData[playerid][P_CurrentTextdraw]][T_TextSizeY]);
                    ShowPlayerDialog(playerid, 2001, DIALOG_STYLE_INPUT, "Area de Clique - Altura", string, "Concluir", "Cancelar");
                    return 1;
                }
                value = floatstr(inputtext);
                
                tData[pData[playerid][P_CurrentTextdraw]][T_TextSizeY] = value;
                UpdateTextdraw(pData[playerid][P_CurrentTextdraw]);
                SaveTDData(pData[playerid][P_CurrentTextdraw], "T_TextSizeY");
                if(pData[playerid][P_ClickAreaOverlayEnabled]) RebuildClickAreaOverlay(playerid);
                
                new string[128];
                format(string, sizeof(string), "Caixa da Textdraw #%d redimensionada com sucesso. X: %.2f, Y: %.2f", 
                    pData[playerid][P_CurrentTextdraw], 
                    tData[pData[playerid][P_CurrentTextdraw]][T_TextSizeX], 
                    tData[pData[playerid][P_CurrentTextdraw]][T_TextSizeY]);
                SendClientMessage(playerid, MSG_COLOR, string);
                pData[playerid][P_KeyEdition] = EDIT_NONE;
                ShowTextDrawDialog(playerid, 5);
            }
            else
            {
                pData[playerid][P_KeyEdition] = EDIT_NONE;
                ShowTextDrawDialog(playerid, 5);
            }
        }

        case 16:
        {
            new info[2048];
            new indices[sizeof(HTML_COLORS)];
            new count = BuildFilteredSortedIndices(playerid, indices, sizeof(indices));
            new start = pData[playerid][P_ColorPageStart];
            if(start < 0) start = 0;
            if(start >= count) {
            	if(count == 0) start = 0; else start = (count - 1) - ((count - 1) % COLOR_PRESET_PAGE_SIZE);
            	pData[playerid][P_ColorPageStart] = start;
            }
            info = "";
            new itemsOnPage = COLOR_PRESET_PAGE_SIZE;
            if(count - start < itemsOnPage) itemsOnPage = count - start;
            new bool:hasPrev = (start > 0);
            if(hasPrev) {
                format(info, sizeof(info), "%s<<< Anterior\n", info);
            }
            if(itemsOnPage <= 0)
            {
            	format(info, sizeof(info), "%s(nenhum resultado)\n", info);
            }
            	        else
	        {
	        	for(new j = 0; j < itemsOnPage; j++)
	        	{
	        		new idx = indices[start + j];
	        		new hexstr[8];
	        		format(hexstr, sizeof(hexstr), "%s", HTML_COLORS[idx][HTMLColorHex]);
	        		format(info, sizeof(info), "%s{%c%c%c%c%c%c}%s{FFFFFF} - %s\n", info, hexstr[1], hexstr[2], hexstr[3], hexstr[4], hexstr[5], hexstr[6], HTML_COLOR_NAMES_PT[idx], HTML_COLORS[idx][HTMLColorHex]);
	        	}
	        }
            new bool:hasNext = (start + itemsOnPage < count);
            if(hasNext) {
                format(info, sizeof(info), "%sMais >>\n", info);
            }
            new title[64];
            new pages = (count + COLOR_PRESET_PAGE_SIZE - 1) / COLOR_PRESET_PAGE_SIZE;
            if(pages <= 0) pages = 1;
            new page = (start / COLOR_PRESET_PAGE_SIZE) + 1;
            format(title, sizeof(title), "Cor da Textdraw (%d/%d)", page, pages);
            ShowPlayerDialog(playerid, dialogid+1574, DIALOG_STYLE_LIST, CreateDialogTitle(playerid, title), info, "Aceitar", "Voltar");
            return true;
        }

        // Search dialog
        case 40:
        {
            new info[256];
            info = "Digite parte do nome em PT ou HEX (#RRGGBB) para filtrar:";
            	                    ShowPlayerDialog(playerid, dialogid+1574, DIALOG_STYLE_INPUT, CreateDialogTitle(playerid, "Buscar cor"), info, "Buscar", "Voltar");
            return true;
        }

        // Group selection
        case 41:
        {
            new info[256];
            info = "Escolha uma familia de cores:\n\n";
            format(info, sizeof(info), "%sTodas\n", info);
            format(info, sizeof(info), "%sBrancos/Cinzas\n", info);
            format(info, sizeof(info), "%sAzuis\n", info);
            format(info, sizeof(info), "%sVerdes\n", info);
            format(info, sizeof(info), "%sAmarelos/Dourados\n", info);
            format(info, sizeof(info), "%sMarrons/Laranjas\n", info);
            format(info, sizeof(info), "%sVermelhos/Rosas\n", info);
            format(info, sizeof(info), "%sRoxos/Violetas", info);
            	                    ShowPlayerDialog(playerid, dialogid+1574, DIALOG_STYLE_LIST, CreateDialogTitle(playerid, "Familia de cores"), info, "OK", "Voltar");
            return true;
        }

        // Sort selection
        case 42:
        {
            new info[128];
            format(info, sizeof(info), "Modo atual: %s\n\nPadrao\nAlfabetica (PT)", pData[playerid][P_ColorSortMode] ? ("ALFABETICA") : ("PADRAO"));
            	                    ShowPlayerDialog(playerid, dialogid+1574, DIALOG_STYLE_LIST, CreateDialogTitle(playerid, "Ordenar cores"), info, "OK", "Voltar");
            return true;
        }

        // Recents/Favorites
        case 43:
        {
            new info[512];
            info = "Recentes:\n";
            new shown;
            	        for(new r = 0; r < pData[playerid][P_RecentCount] && r < 10; r++)
	        {
	            new idx = pData[playerid][P_RecentColors][r];
	            if(idx >= 0 && idx < sizeof(HTML_COLORS))
	            {
	                new hexstr[8];
	                format(hexstr, sizeof(hexstr), "%s", HTML_COLORS[idx][HTMLColorHex]);
	                format(info, sizeof(info), "%s{%c%c%c%c%c%c}%s{FFFFFF} - %s\n", info, hexstr[1], hexstr[2], hexstr[3], hexstr[4], hexstr[5], hexstr[6], HTML_COLOR_NAMES_PT[idx], HTML_COLORS[idx][HTMLColorHex]);
	                shown++;
	            }
	        }
            if(!shown) format(info, sizeof(info), "%s(nenhum)\n", info);
            	                    ShowPlayerDialog(playerid, dialogid+1574, DIALOG_STYLE_LIST, CreateDialogTitle(playerid, "Recentes"), info, "OK", "Voltar");
            return true;
        }

        // Alpha quick selection
        case 44:
        {
            new info[160];
            info = "Selecione a transparencia (alpha):\n\n100% (255)\n75% (191)\n50% (127)\n25% (63)\nPersonalizar\nAlternar favorito";
            ShowPlayerDialog(playerid, dialogid+1574, DIALOG_STYLE_LIST, CreateDialogTitle(playerid, "Transparencia"), info, "OK", "Voltar");
            return true;
        }

        case 1614: // Search input
        {
            if(response)
            {
                // Save filter and reset page
                strmid(pData[playerid][P_ColorFilter], inputtext, 0, strlen(inputtext), 32);
                pData[playerid][P_ColorPageStart] = 0;
                ShowTextDrawDialog(playerid, 16);
            }
            else ShowTextDrawDialog(playerid, 13);
        }

        case 1615: // Group selection
        {
            if(response)
            {
                // listitem: 0 Todas, 1..7 groups
                pData[playerid][P_ColorGroup] = listitem;
                pData[playerid][P_ColorPageStart] = 0;
                ShowTextDrawDialog(playerid, 16);
            }
            else ShowTextDrawDialog(playerid, 13);
        }

        case 1616: // Sort selection
        {
            if(response)
            {
                pData[playerid][P_ColorSortMode] = listitem; // 0 padrao, 1 alfabetica
                pData[playerid][P_ColorPageStart] = 0;
                ShowTextDrawDialog(playerid, 16);
            }
            else ShowTextDrawDialog(playerid, 13);
        }

        case 1617: // Recents list
        {
            if(response)
            {
                new idx = -1;
                if(listitem >= 0 && listitem < pData[playerid][P_RecentCount])
                    idx = pData[playerid][P_RecentColors][listitem];
                if(idx >= 0 && idx < sizeof(HTML_COLORS))
                {
                    // Apply selected recent color immediately with full opacity (no transparency prompt)
                    new alpha = 255;
                    new hexstr[8];
                    format(hexstr, sizeof(hexstr), "%s", HTML_COLORS[idx][HTMLColorHex]); // #RRGGBB
                    new rhex[3], ghex[3], bhex[3];
                    format(rhex, sizeof(rhex), "%c%c", hexstr[1], hexstr[2]);
                    format(ghex, sizeof(ghex), "%c%c", hexstr[3], hexstr[4]);
                    format(bhex, sizeof(bhex), "%c%c", hexstr[5], hexstr[6]);
                    new col = RGB(HexToInt(rhex), HexToInt(ghex), HexToInt(bhex), alpha);
                    if(pData[playerid][P_ColorEdition] == COLOR_TEXT)
                        tData[pData[playerid][P_CurrentTextdraw]][T_Color] = col;
                    else if(pData[playerid][P_ColorEdition] == COLOR_OUTLINE)
                        tData[pData[playerid][P_CurrentTextdraw]][T_BackColor] = col;
                    else if(pData[playerid][P_ColorEdition] == COLOR_BOX)
                        tData[pData[playerid][P_CurrentTextdraw]][T_BoxColor] = col;
                    UpdateTextdraw(pData[playerid][P_CurrentTextdraw]);
                    SaveTDData(pData[playerid][P_CurrentTextdraw], "T_Color");
                    SaveTDData(pData[playerid][P_CurrentTextdraw], "T_BackColor");
                    SaveTDData(pData[playerid][P_CurrentTextdraw], "T_BoxColor");
                    // Push to recents (front)
                    for(new k = 9; k > 0; k--) pData[playerid][P_RecentColors][k] = pData[playerid][P_RecentColors][k-1];
                    pData[playerid][P_RecentColors][0] = idx;
                    if(pData[playerid][P_RecentCount] < 10) pData[playerid][P_RecentCount]++;
                    new string[128];
                    format(string, sizeof(string), "A cor da Textdraw #%d foi alterada.", pData[playerid][P_CurrentTextdraw]);
                    SendClientMessage(playerid, MSG_COLOR, string);
                    // Back to appropriate menu
                    if(pData[playerid][P_ColorEdition] == COLOR_TEXT) ShowTextDrawDialog(playerid, 5);
                    else if(pData[playerid][P_ColorEdition] == COLOR_OUTLINE) ShowTextDrawDialog(playerid, 20);
                    else if(pData[playerid][P_ColorEdition] == COLOR_BOX) ShowTextDrawDialog(playerid, 24);
                }
                else ShowTextDrawDialog(playerid, 13);
            }
            else ShowTextDrawDialog(playerid, 13);
        }
        case 1618: // Alpha quick selection
        {
            if(response)
            {
                new alpha = 255;
                switch(listitem)
                {
                    case 0: alpha = 255;
                    case 1: alpha = 191;
                    case 2: alpha = 127;
                    case 3: alpha = 63;
                    case 4:
                    {
                        // Custom input
                        ShowTextDrawDialog(playerid, 45);
                        return true;
                    }
                    case 5:
                    {
                        // Toggle favorite for pending color and redisplay alpha menu
                        new idxf = pData[playerid][P_PendingColorIndex];
                        if(idxf >= 0 && idxf < sizeof(HTML_COLORS))
                        {
                            ToggleFavoriteColor(playerid, idxf);
                        }
                        ShowTextDrawDialog(playerid, 44);
                        return true;
                    }
                }
                pData[playerid][P_ColorAlpha] = alpha;
                // Apply pending color
                new idx = pData[playerid][P_PendingColorIndex];
                if(idx >= 0 && idx < sizeof(HTML_COLORS))
                {
                    // Derive RGB from HEX to avoid divergence
                    new hexstr[8];
                    format(hexstr, sizeof(hexstr), "%s", HTML_COLORS[idx][HTMLColorHex]); // #RRGGBB
                    new rhex[3], ghex[3], bhex[3];
                    format(rhex, sizeof(rhex), "%c%c", hexstr[1], hexstr[2]);
                    format(ghex, sizeof(ghex), "%c%c", hexstr[3], hexstr[4]);
                    format(bhex, sizeof(bhex), "%c%c", hexstr[5], hexstr[6]);
                    new col = RGB(HexToInt(rhex), HexToInt(ghex), HexToInt(bhex), alpha);
                    if(pData[playerid][P_ColorEdition] == COLOR_TEXT)
                        tData[pData[playerid][P_CurrentTextdraw]][T_Color] = col;
                    else if(pData[playerid][P_ColorEdition] == COLOR_OUTLINE)
                        tData[pData[playerid][P_CurrentTextdraw]][T_BackColor] = col;
                    else if(pData[playerid][P_ColorEdition] == COLOR_BOX)
                        tData[pData[playerid][P_CurrentTextdraw]][T_BoxColor] = col;
                    UpdateTextdraw(pData[playerid][P_CurrentTextdraw]);
                    SaveTDData(pData[playerid][P_CurrentTextdraw], "T_Color");
                    SaveTDData(pData[playerid][P_CurrentTextdraw], "T_BackColor");
                    SaveTDData(pData[playerid][P_CurrentTextdraw], "T_BoxColor");
                    // Push to recents (front)
                    for(new k = 9; k > 0; k--) pData[playerid][P_RecentColors][k] = pData[playerid][P_RecentColors][k-1];
                    pData[playerid][P_RecentColors][0] = idx;
                    if(pData[playerid][P_RecentCount] < 10) pData[playerid][P_RecentCount]++;
                    new string[128];
                    format(string, sizeof(string), "A cor da Textdraw #%d foi alterada.", pData[playerid][P_CurrentTextdraw]);
                    SendClientMessage(playerid, MSG_COLOR, string);
                }
                // Back to appropriate menu
                if(pData[playerid][P_ColorEdition] == COLOR_TEXT) ShowTextDrawDialog(playerid, 5);
                else if(pData[playerid][P_ColorEdition] == COLOR_OUTLINE) ShowTextDrawDialog(playerid, 20);
                else if(pData[playerid][P_ColorEdition] == COLOR_BOX) ShowTextDrawDialog(playerid, 24);
            }
            else ShowTextDrawDialog(playerid, 16);
        }

        case 1619: // Custom alpha input
        {
            if(response)
            {
                new a = strval(inputtext);
                if(a < 0 || a > 255) { ShowTextDrawDialog(playerid, 44); return true; }
                pData[playerid][P_ColorAlpha] = a;
                // If there is a pending preset color, apply alpha to that preset's RGB.
                // Otherwise, update the alpha of the current color (keep existing RGB).
                new idx = pData[playerid][P_PendingColorIndex];
                if(idx >= 0 && idx < sizeof(HTML_COLORS))
                {
                    new hexstr[8]; new rhex[3], ghex[3], bhex[3];
                    format(hexstr, sizeof(hexstr), "%s", HTML_COLORS[idx][HTMLColorHex]);
                    format(rhex, sizeof(rhex), "%c%c", hexstr[1], hexstr[2]);
                    format(ghex, sizeof(ghex), "%c%c", hexstr[3], hexstr[4]);
                    format(bhex, sizeof(bhex), "%c%c", hexstr[5], hexstr[6]);
                    new col = RGB(HexToInt(rhex), HexToInt(ghex), HexToInt(bhex), a);
                    if(pData[playerid][P_ColorEdition] == COLOR_TEXT)
                        tData[pData[playerid][P_CurrentTextdraw]][T_Color] = col;
                    else if(pData[playerid][P_ColorEdition] == COLOR_OUTLINE)
                        tData[pData[playerid][P_CurrentTextdraw]][T_BackColor] = col;
                    else if(pData[playerid][P_ColorEdition] == COLOR_BOX)
                        tData[pData[playerid][P_CurrentTextdraw]][T_BoxColor] = col;
                    UpdateTextdraw(pData[playerid][P_CurrentTextdraw]);
                    SaveTDData(pData[playerid][P_CurrentTextdraw], "T_Color");
                    SaveTDData(pData[playerid][P_CurrentTextdraw], "T_BackColor");
                    SaveTDData(pData[playerid][P_CurrentTextdraw], "T_BoxColor");
                    for(new k = 9; k > 0; k--) pData[playerid][P_RecentColors][k] = pData[playerid][P_RecentColors][k-1];
                    pData[playerid][P_RecentColors][0] = idx;
                    if(pData[playerid][P_RecentCount] < 10) pData[playerid][P_RecentCount]++;
                    new string[128];
                    format(string, sizeof(string), "A cor da Textdraw #%d foi alterada.", pData[playerid][P_CurrentTextdraw]);
                    SendClientMessage(playerid, MSG_COLOR, string);
                }
                else
                {
                    // Modify only alpha of the currently edited color
                    new oldcol;
                    if(pData[playerid][P_ColorEdition] == COLOR_TEXT)
                        oldcol = tData[pData[playerid][P_CurrentTextdraw]][T_Color];
                    else if(pData[playerid][P_ColorEdition] == COLOR_OUTLINE)
                        oldcol = tData[pData[playerid][P_CurrentTextdraw]][T_BackColor];
                    else // COLOR_BOX
                        oldcol = tData[pData[playerid][P_CurrentTextdraw]][T_BoxColor];

                    new newcol = (a << 24) | (oldcol & 0x00FFFFFF);
                    if(pData[playerid][P_ColorEdition] == COLOR_TEXT)
                        tData[pData[playerid][P_CurrentTextdraw]][T_Color] = newcol;
                    else if(pData[playerid][P_ColorEdition] == COLOR_OUTLINE)
                        tData[pData[playerid][P_CurrentTextdraw]][T_BackColor] = newcol;
                    else if(pData[playerid][P_ColorEdition] == COLOR_BOX)
                        tData[pData[playerid][P_CurrentTextdraw]][T_BoxColor] = newcol;
                    UpdateTextdraw(pData[playerid][P_CurrentTextdraw]);
                    SaveTDData(pData[playerid][P_CurrentTextdraw], "T_Color");
                    SaveTDData(pData[playerid][P_CurrentTextdraw], "T_BackColor");
                    SaveTDData(pData[playerid][P_CurrentTextdraw], "T_BoxColor");
                    new string2[128];
                    format(string2, sizeof(string2), "Transparencia da Textdraw #%d atualizada para %d.", pData[playerid][P_CurrentTextdraw], a);
                    SendClientMessage(playerid, MSG_COLOR, string2);
                }
                if(pData[playerid][P_ColorEdition] == COLOR_TEXT) ShowTextDrawDialog(playerid, 5);
                else if(pData[playerid][P_ColorEdition] == COLOR_OUTLINE) ShowTextDrawDialog(playerid, 20);
                else if(pData[playerid][P_ColorEdition] == COLOR_BOX) ShowTextDrawDialog(playerid, 24);
            }
            else
            {
                // If coming from preset selection flow, go back to alpha menu; otherwise back to color menu
                if(pData[playerid][P_PendingColorIndex] >= 0) ShowTextDrawDialog(playerid, 44);
                else ShowTextDrawDialog(playerid, 13);
            }
        }
        case 45:
        {
            new info[128];
            info = "Digite o alpha (0-255):";
            ShowPlayerDialog(playerid, dialogid+1574, DIALOG_STYLE_INPUT, CreateDialogTitle(playerid, "Transparencia"), info, "OK", "Voltar");
            return true;
        }
    }
    
	return 1;
}

// =============================================================================
// Functions.
// =============================================================================

forward ShowTextDrawDialogEx( playerid, dialogid );
public ShowTextDrawDialogEx( playerid, dialogid ) ShowTextDrawDialog( playerid, dialogid );

stock ShowTextDrawDialog( playerid, dialogid, aux=0, aux2=0 )
{
    /*	Shows a specific dialog for a specific player
	    @playerid:      ID of the player to show the dialog to.
	    @dialogid:      ID of the dialog to show.
	    @aux:           Auxiliary variable. Works to make variations of certain dialogs.
	    @aux2:          Auxiliary variable. Works to make variations of certain dialogs.

	    -Returns:
	    true on success, false on fail.
	*/

	switch(dialogid)
	{
	    case 0: // Select project.
	    {
            new info[256];
		    format(info, sizeof(info), "%sNovo Projeto\n", info);
		    format(info, sizeof(info), "%sCarregar Projeto\n", info);
		    format(info, sizeof(info), "%sExcluir Projeto", info);
		    ShowPlayerDialog(playerid, dialogid+1574, DIALOG_STYLE_LIST, CreateDialogTitle(playerid, "Inicialização"), info, "OK", "Cancelar");
		    return true;
	    }
	    
	    case 1:
	    {
	        new info[256];
	                if(!aux) 			info = "Digite o nome do novo arquivo de projeto.\n";
        else if(aux == 1)   info = "ERRO: O nome e muito longo, tente novamente.\n";
        else if(aux == 2)   info = "ERRO: Esse nome de arquivo ja existe, tente novamente.\n";
        else if(aux == 3)   info = "ERRO: Esse nome de arquivo contem caracteres ilegais. Voce nao pode\ncriar subdiretorios. Tente novamente.";
	        ShowPlayerDialog(playerid, dialogid+1574, DIALOG_STYLE_INPUT, CreateDialogTitle(playerid, "Novo projeto"), info, "OK", "Voltar");
	        return true;
	    }
	    
	    case 2:
	    {
	        // Store in a var if he's deleting or loading.
	        if(aux == 2) 	pData[playerid][P_CurrentMenu] = DELETING;
	        else            pData[playerid][P_CurrentMenu] = LOADING;
	        
			new info[1024];
			if(fexist("tdlist.lst"))
	        {
				if(aux != 2)	info = "Nome de arquivo personalizado...";
				else    		info = "<< Voltar";
		        new File:tdlist = fopen("tdlist.lst", io_read),
					line[128];
                while(fread(tdlist, line))
                {
		            format(info, sizeof(info), "%s\n%s", info, line);
		        }
		        
		        ShowPlayerDialog(playerid, dialogid+1574, DIALOG_STYLE_LIST, CreateDialogTitle(playerid, "Carregar projeto"), info, "OK", "Voltar");
		        fclose(tdlist);
	        }
	        else
	        {
	            if(aux) format(info, sizeof(info), "%sNao foi possivel encontrar tdlist.lst.\n", info);
			    format(info, sizeof(info), "%sDigite manualmente o nome do arquivo de projeto que voce quer\n", info);
			    if(aux != 2) 	format(info, sizeof(info), "%sabrir:\n", info);
			    else            format(info, sizeof(info), "%sexcluir:\n", info);
			    
			    if(aux != 2)	ShowPlayerDialog(playerid, dialogid+1574, DIALOG_STYLE_INPUT, CreateDialogTitle(playerid, "Carregar projeto"), info, "OK", "Voltar");
			    else            ShowPlayerDialog(playerid, dialogid+1574, DIALOG_STYLE_INPUT, CreateDialogTitle(playerid, "Excluir projeto"), info, "OK", "Voltar");
		    }
	        return true;
	    }
	    
	    case 3:
	    {
			ShowPlayerDialog(playerid, dialogid+1574, DIALOG_STYLE_INPUT, CreateDialogTitle(playerid, "Carregar projeto"), \
	 		"Digite manualmente o nome do arquivo do projeto\n que deseja carregar:\n", "OK", "Voltar");
			return true;
	    }
	    
	    case 4: // Main edition menu (shows all the textdraws and lets you create a new one).
	    {
	        new info[1024],
				shown;
	        format(info, sizeof(info), "%sCriar nova Textdraw...", info);
	        shown ++;
	        format(info, sizeof(info), "%s\nExportar projeto...", info);
	        shown ++;
	        format(info, sizeof(info), "%s\nFechar projeto...", info);
	        shown ++;
	        // Aux here is used to indicate from which TD show the list from.
	        pData[playerid][P_DialogPage] = aux;
	        for(new i=aux; i < MAX_TEXTDRAWS; i++)
	        {
	            if(tData[i][T_Created])
	            {
	                shown ++;
					if(shown == 12)
					{
						format(info, sizeof(info), "%s\nMais >>", info);
						break;
					}
					
	                new PieceOfText[PREVIEW_CHARS];
	                if(strlen(tData[i][T_Text]) > sizeof(PieceOfText))
	                {
	                    strmid(PieceOfText, tData[i][T_Text], 0, PREVIEW_CHARS, PREVIEW_CHARS);
	                    format(info, sizeof(info), "%s\nTDraw %d: '%s [...]'", info, i, PieceOfText);
	                }
					else
					{
					    format(info, sizeof(info), "%s\nTDraw %d: '%s'", info, i, tData[i][T_Text]);
					}
	            }
	        }
	        ShowPlayerDialog(playerid, dialogid+1574, DIALOG_STYLE_LIST, CreateDialogTitle(playerid, "Seleção de Textdraw"), info, "OK", "Cancelar");
	        return true;
	    }
	    
	    case 5:
	    {
	        new p_current = pData[playerid][P_CurrentTextdraw];
	    
	        new info[1024];
	        format(info, sizeof(info), "%sMudar Nome da Textdraw\n", info);
	        format(info, sizeof(info), "%sMudar Posicao da Textdraw\n", info);
	        format(info, sizeof(info), "%sAlinhar Textdraw\n", info);
	        format(info, sizeof(info), "%sMudar Cor do Texto da Textdraw\n", info);
	        format(info, sizeof(info), "%sMudar Fonte do Texto da Textdraw\n", info);
	        format(info, sizeof(info), "%sDar Espaco no Texto\n", info);
	        format(info, sizeof(info), "%sMudar o Tamanho do Texto da Textdraw\n", info);
	        format(info, sizeof(info), "%sColocar Bordas No Texto da Textdraw\n", info);
	        format(info, sizeof(info), "%sColocar Fundo No Texto da Textdraw\n", info);
	        format(info, sizeof(info), "%sAjustar Area de Clique da Textdraw\n", info);
	        format(info, sizeof(info), "%sTestar Se a Textdraw Esta Clicavel: %s\n", info, pData[playerid][P_ClickTestMode] ? ("{00DD00}ATIVADO") : ("{DD0000}DESATIVADO"));
	        format(info, sizeof(info), "%sAlterar O Modo da Textdraw: %s\n", info, tData[p_current][T_Mode] == 0 ? ("{00AAFF}GLOBAL") : ("{00AAFF}PLAYER"));
	        format(info, sizeof(info), "%sDefinir Para Poder Selecionar a Textdraw\n", info);
	        format(info, sizeof(info), "%sConfigurar Modelo 3D da Textdraw\n", info);
	        format(info, sizeof(info), "%sFazer Uma Copia Desta Textdraw\n", info);
	        format(info, sizeof(info), "%sApagar Esta Textdraw", info);
	        
	        new title[40];
	        format(title, sizeof(title), "Textdraw %d", p_current);
	        
	        ShowPlayerDialog(playerid, dialogid+1574, DIALOG_STYLE_LIST, CreateDialogTitle(playerid, title), info, "OK", "Cancelar");
	        return true;
	    }
	    
	    case 6:
	    {
	        new info[256];
	        		format(info, sizeof(info), "%sTem certeza que deseja apagar o\n", info);
		format(info, sizeof(info), "%sprojeto '%s'?\n\n", info, GetFileNameFromLst("tdlist.lst", pData[playerid][P_Aux]));
		format(info, sizeof(info), "%sATENCAO: Esta acao nao pode ser desfeita!", info);
			
		ShowPlayerDialog(playerid, dialogid+1574, DIALOG_STYLE_MSGBOX, CreateDialogTitle(playerid, "Confirmar exclusão"), info, "Sim", "Não");
	        return true;
	    }
	    
	    case 7:
	    {
	        new info[256];
	        		format(info, sizeof(info), "%sTem certeza que deseja apagar a\n", info);
		format(info, sizeof(info), "%sTextdraw numero %d?\n\n", info, pData[playerid][P_CurrentTextdraw]);
		format(info, sizeof(info), "%sATENCAO: Esta acao nao pode ser desfeita!", info);
			
		ShowPlayerDialog(playerid, dialogid+1574, DIALOG_STYLE_MSGBOX, CreateDialogTitle(playerid, "Confirmar exclusão"), info, "Sim", "Não");
	        return true;
	    }
	    
	    case 8:
	    {
	        new info[1024];
	        info = "Digite o novo texto da textdraw.\n\nTexto atual:\n";
	        format(info, sizeof(info), "%s%s\n\n", info, tData[pData[playerid][P_CurrentTextdraw]][T_Text]);
	        ShowPlayerDialog(playerid, dialogid+1574, DIALOG_STYLE_INPUT, CreateDialogTitle(playerid, "Texto da Textdraw"), info, "Aceitar", "Voltar");
	        return true;
	    }
	    
	    case 9:
	    {
	        new info[256];
	        info = "";
	        format(info, sizeof(info), "%sDigitar posicao exata (mais preciso)\n", info);
	        format(info, sizeof(info), "%sMover pelo teclado", info);
	        ShowPlayerDialog(playerid, dialogid+1574, DIALOG_STYLE_LIST, CreateDialogTitle(playerid, "Posição da Textdraw"), info, "OK", "Voltar");
	        return true;
	    }
	    
	    case 10:
	    {
	        // aux is 0 for X, 1 for Y.
	        // aux2 is the type of error message. 0 for no error.
	        new info[256];
	        if(aux2 == 1) info = "ERRO: Voce precisa digitar um numero valido.\n\n";
	        
	        format(info, sizeof(info), "%sDigite a nova posicao ", info);
	        if(aux == 0) 		format(info, sizeof(info), "%shorizontal (X)", info);
	        else if(aux == 1)   format(info, sizeof(info), "%svertical (Y)", info);
         	format(info, sizeof(info), "%s da textdraw\n", info);
         	
        	pData[playerid][P_Aux] = aux; // To know if he's editing X or Y.
	        ShowPlayerDialog(playerid, dialogid+1574, DIALOG_STYLE_INPUT, CreateDialogTitle(playerid, "Posicao da Textdraw"), info, "Aceitar", "Voltar");
	        return true;
	    }
	    
	    case 11:
	    {
	        new info[256];
	        info = "";
	        format(info, sizeof(info), "%sAlinhar a Esquerda\n", info);
	        format(info, sizeof(info), "%sCentralizar o Texto\n", info);
	        format(info, sizeof(info), "%sAlinhar a Direita\n", info);
	        format(info, sizeof(info), "%sSem Alinhamento (padrao)", info);
	        ShowPlayerDialog(playerid, dialogid+1574, DIALOG_STYLE_LIST, CreateDialogTitle(playerid, "Alinhamento da Textdraw"), info, "OK", "Voltar");
	        return true;
	    }
	    
	    case 12:
	    {
	        new info[256];
	        info = "";
	        format(info, sizeof(info), "%sEspacamento Proporcional (recomendado)\n", info);
	        format(info, sizeof(info), "%sEspacamento Fixo", info);
	        ShowPlayerDialog(playerid, dialogid+1574, DIALOG_STYLE_LIST, CreateDialogTitle(playerid, "Proporcionalidade da Textdraw"), info, "OK", "Voltar");
	        return true;
	    }
	    case 13:
	    {
	        new info[512];
	        info = "";
	        format(info, sizeof(info), "%sDigitar codigo de cor (hexadecimal)\n", info);
	        format(info, sizeof(info), "%sMisturar cores (RGB)\n", info);
	        format(info, sizeof(info), "%sEscolher cor pronta\n", info);
	        format(info, sizeof(info), "%sBuscar por nome/HEX\n", info);
	        format(info, sizeof(info), "%sAgrupar por familia\n", info);
	        format(info, sizeof(info), "%sOrdenar (padrao/alfabetica)\n", info);
	        format(info, sizeof(info), "%sRecentes/Favoritas\n", info);
	        format(info, sizeof(info), "%sAlterar transparencia (alpha)", info);
	        ShowPlayerDialog(playerid, dialogid+1574, DIALOG_STYLE_LIST, CreateDialogTitle(playerid, "Cor da Textdraw"), info, "OK", "Voltar");
	        return true;
	    }
	    
	    case 14:
	    {
	        new info[256];
	        if(aux) info = "ERRO: Codigo de cor invalido. Use formato: FFFFFF\n\n";
	        format(info, sizeof(info), "%sDigite o codigo de cor (exemplo: FFFFFF para branco):\n", info);
	        ShowPlayerDialog(playerid, dialogid+1574, DIALOG_STYLE_INPUT, CreateDialogTitle(playerid, "Cor da Textdraw"), info, "OK", "Voltar");
	        return true;
	    }
	    
	    case 15:
	    {
	        // aux is 0 for red, 1 for green, 2 for blue, and 3 for alpha.
	        // aux2 is the type of error message. 0 for no error.
	        new info[256];
	        if(aux2 == 1) 		info = "ERRO: O valor deve estar entre 0 e 255.\n\n";
	        else if(aux2 == 2) 	info = "ERRO: Voce precisa digitar um numero.\n\n";

	        	        format(info, sizeof(info), "%sDigite a quantidade de ", info);
	        if(aux == 0) 		format(info, sizeof(info), "%sVERMELHO", info);
	        else if(aux == 1)   format(info, sizeof(info), "%sVERDE", info);
	        else if(aux == 2)   format(info, sizeof(info), "%sAZUL", info);
	        else if(aux == 3)   format(info, sizeof(info), "%sTRANSPARENCIA", info);
         	format(info, sizeof(info), "%s (0-255):\n", info);
         	format(info, sizeof(info), "%s0 = sem cor, 255 = cor maxima", info);

        	 pData[playerid][P_Aux] = aux; // To know what color he's editing.
	        ShowPlayerDialog(playerid, dialogid+1574, DIALOG_STYLE_INPUT, CreateDialogTitle(playerid, "Cor da Textdraw"), info, "OK", "Voltar");
	        return true;
	    }
	    
	    case 16:
	    {
	        new info[2048];
	        new indices[sizeof(HTML_COLORS)];
	        new count = BuildFilteredSortedIndices(playerid, indices, sizeof(indices));
	        new start = pData[playerid][P_ColorPageStart];
	        if(start < 0) start = 0;
	        if(start >= count) {
	        	if(count == 0) start = 0; else start = (count - 1) - ((count - 1) % COLOR_PRESET_PAGE_SIZE);
	        	pData[playerid][P_ColorPageStart] = start;
	        }
	        info = "";
	        new itemsOnPage = COLOR_PRESET_PAGE_SIZE;
	        if(count - start < itemsOnPage) itemsOnPage = count - start;
	        new bool:hasPrev = (start > 0);
	        if(hasPrev) {
	            format(info, sizeof(info), "%s<<< Anterior\n", info);
	        }
	        if(itemsOnPage <= 0)
	        {
	        	format(info, sizeof(info), "%s(nenhum resultado)\n", info);
	        }
	        else
	        {
	        	for(new j = 0; j < itemsOnPage; j++)
	        	{
	        		new idx = indices[start + j];
	        		new hexstr[8];
	        		format(hexstr, sizeof(hexstr), "%s", HTML_COLORS[idx][HTMLColorHex]);
	        		format(info, sizeof(info), "%s{%c%c%c%c%c%c}%s{FFFFFF} - %s\n", info, hexstr[1], hexstr[2], hexstr[3], hexstr[4], hexstr[5], hexstr[6], HTML_COLOR_NAMES_PT[idx], HTML_COLORS[idx][HTMLColorHex]);
	        	}
	        }
	        new bool:hasNext = (start + itemsOnPage < count);
	        if(hasNext) {
	            format(info, sizeof(info), "%sMais >>", info);
	        }
	        new title[64];
	        new pages = (count + COLOR_PRESET_PAGE_SIZE - 1) / COLOR_PRESET_PAGE_SIZE;
	        if(pages <= 0) pages = 1;
	        new page = (start / COLOR_PRESET_PAGE_SIZE) + 1;
	        format(title, sizeof(title), "Cor da Textdraw (%d/%d)", page, pages);
	        ShowPlayerDialog(playerid, dialogid+1574, DIALOG_STYLE_LIST, CreateDialogTitle(playerid, title), info, "Aceitar", "Voltar");
	        return true;
	    }
	    
	    case 17:
	    {
	        new info[256];
	        info = "";
	        format(info, sizeof(info), "%sFonte Padrao (tipo 0)\n", info);
	        format(info, sizeof(info), "%sFonte Grande (tipo 1)\n", info);
	        format(info, sizeof(info), "%sFonte Pequena (tipo 2)\n", info);
	        format(info, sizeof(info), "%sFonte Monospace (tipo 3)\n", info);
	        format(info, sizeof(info), "%sFonte Estilizada (tipo 4)\n", info);
	        format(info, sizeof(info), "%sFonte para Modelo 3D (tipo 5)", info);
	        ShowPlayerDialog(playerid, dialogid+1574, DIALOG_STYLE_LIST, CreateDialogTitle(playerid, "Fonte da Textdraw"), info, "OK", "Voltar");
	        return true;
	    }
	    
	    case 18:
	    {
	        new info[256];
	        info = "";
	        format(info, sizeof(info), "%sDigitar tamanho exato (mais preciso)\n", info);
	        format(info, sizeof(info), "%sRedimensionar pelo teclado", info);
	        ShowPlayerDialog(playerid, dialogid+1574, DIALOG_STYLE_LIST, CreateDialogTitle(playerid, "Tamanho da fonte"), info, "OK", "Voltar");
	        return true;
	    }
	    
	    case 19:
	    {
	        // aux is 0 for X, 1 for Y.
	        // aux2 is the type of error message. 0 for no error.
	        new info[256];
	        if(aux2 == 1) info = "ERRO: Voce precisa digitar um numero valido.\n\n";

	        format(info, sizeof(info), "%sDigite o novo tamanho ", info);
	        if(aux == 0) 		format(info, sizeof(info), "%shorizontal (X)", info);
	        else if(aux == 1)   format(info, sizeof(info), "%svertical (Y)", info);
         	format(info, sizeof(info), "%s das letras:\n", info);

        	pData[playerid][P_Aux] = aux; // To know if he's editing X or Y.
	        ShowPlayerDialog(playerid, dialogid+1574, DIALOG_STYLE_INPUT, CreateDialogTitle(playerid, "Tamanho da Textdraw"), info, "OK", "Voltar");
	        return true;
	    }
	    
	    case 20:
	    {
	        new info[256];
	        if(tData[pData[playerid][P_CurrentTextdraw]][T_Outline] == 1)	info = "Desligar Contorno";
	        else                                                            info = "Ligar Contorno";
	        format(info, sizeof(info), "%s\nAjustar Tamanho da Sombra\nMudar Cor do Contorno\nFinalizar Edicao do Contorno", info);
	        ShowPlayerDialog(playerid, dialogid+1574, DIALOG_STYLE_LIST, CreateDialogTitle(playerid, "Contorno da Textdraw"), info, "OK", "Voltar");
	        return true;
	    }
	    case 21:
	    {
	        new info[256];
	        info = "";
	        format(info, sizeof(info), "%sSem Sombra\n", info);
	        format(info, sizeof(info), "%sSombra Pequena\n", info);
	        format(info, sizeof(info), "%sSombra Media\n", info);
	        format(info, sizeof(info), "%sSombra Grande\n", info);
	        format(info, sizeof(info), "%sSombra Extra Grande\n", info);
	        format(info, sizeof(info), "%sSombra Maxima\n", info);
	        format(info, sizeof(info), "%sTamanho Personalizado", info);
	        ShowPlayerDialog(playerid, dialogid+1574, DIALOG_STYLE_LIST, CreateDialogTitle(playerid, "Sombra do contorno"), info, "OK", "Voltar");
	        return true;
	    }
	    case 22:
	    {
	        new info[256];
	        if(aux) info = "ERRO: Voce precisa digitar um numero valido.\n\n";
	        format(info, sizeof(info), "%sDigite o tamanho da sombra (0-5):\n", info);
	        ShowPlayerDialog(playerid, dialogid+1574, DIALOG_STYLE_INPUT, CreateDialogTitle(playerid, "Sombra do contorno"), info, "OK", "Voltar");
	        return true;
	    }
	    
	    case 23:
	    {
	        new info[256];
	        info = "";
	        format(info, sizeof(info), "%sAtivar Fundo\n", info);
	        format(info, sizeof(info), "%sDesativar Fundo", info);
	        ShowPlayerDialog(playerid, dialogid+1574, DIALOG_STYLE_LIST, CreateDialogTitle(playerid, "Caixa da Textdraw"), info, "OK", "Voltar");
	        return true;
	    }
	    
	    case 24:
	    {
	        new info[256];
	        info = "";
	        format(info, sizeof(info), "%sDesativar Fundo\n", info);
	        format(info, sizeof(info), "%sAjustar Tamanho do Fundo\n", info);
	        format(info, sizeof(info), "%sMudar Cor do Fundo", info);
	        ShowPlayerDialog(playerid, dialogid+1574, DIALOG_STYLE_LIST, CreateDialogTitle(playerid, "Caixa da Textdraw"), info, "OK", "Voltar");
	        return true;
	    }
	    
	    case 25:
	    {
	        new info[512];
	        info = "";
	        format(info, sizeof(info), "%sCodigo Simples (para gamemode)\n", info);
	        format(info, sizeof(info), "%sFilterscript Completo\n", info);
	        format(info, sizeof(info), "%sPlayerTextDraw (para cada jogador)\n", info);
	        format(info, sizeof(info), "%sModo Misto (ambos)", info);
	        ShowPlayerDialog(playerid, dialogid+1574, DIALOG_STYLE_LIST, CreateDialogTitle(playerid, "Exportação de Textdraw"), info, "OK", "Voltar");
	        return true;
	    }
	    
	    case 26:
	    {
	        new info[1024];
	        info = "";
	        format(info, sizeof(info), "%sSempre visivel\n", info);
	        format(info, sizeof(info), "%sApenas na selecao de classe\n", info);
	        format(info, sizeof(info), "%sApenas dentro de veiculos\n", info);
	        format(info, sizeof(info), "%sApenas com comando\n", info);
	        format(info, sizeof(info), "%sA cada X segundos\n", info);
	        format(info, sizeof(info), "%sApos matar alguem", info);
	        ShowPlayerDialog(playerid, dialogid+1574, DIALOG_STYLE_LIST, CreateDialogTitle(playerid, "Exportação de Textdraw"), info, "OK", "Voltar");
	        return true;
	    }
	    
	    case 27:
	    {
	        new info[128];
	        info = "Digite o comando para mostrar a textdraw:\n";
	        ShowPlayerDialog(playerid, dialogid+1574, DIALOG_STYLE_INPUT, CreateDialogTitle(playerid, "Exportação de Textdraw"), info, "OK", "Voltar");
	        return true;
	    }
	    
	    case 28:
	    {
	        new info[128];
	        info = "Por quanto tempo a textdraw deve ficar na tela?\n";
	        format(info, sizeof(info), "%sDigite 0 para esconder com o mesmo comando.\n", info);
	        ShowPlayerDialog(playerid, dialogid+1574, DIALOG_STYLE_INPUT, CreateDialogTitle(playerid, "Exportação de Textdraw"), info, "OK", "Voltar");
	        return true;
	    }
	    
	    case 29:
	    {
	        new info[128];
	        info = "De quanto em quanto tempo a textdraw deve aparecer?\nDigite o tempo em segundos:\n";
	        ShowPlayerDialog(playerid, dialogid+1574, DIALOG_STYLE_INPUT, CreateDialogTitle(playerid, "Exportação de Textdraw"), info, "OK", "Voltar");
	        return true;
	    }

	    case 30:
	    {
	        new info[128];
	        info = "Por quanto tempo a textdraw deve ficar na tela?\nDigite o tempo em segundos:\n";
	        ShowPlayerDialog(playerid, dialogid+1574, DIALOG_STYLE_INPUT, CreateDialogTitle(playerid, "Exportação de Textdraw"), info, "OK", "Voltar");
	        return true;
	    }
	    
	    case 31:
	    {
	        new info[128];
	        info = "Por quanto tempo a textdraw deve ficar na tela?\nDigite o tempo em segundos:\n";
	        ShowPlayerDialog(playerid, dialogid+1574, DIALOG_STYLE_INPUT, CreateDialogTitle(playerid, "Exportação de Textdraw"), info, "OK", "Voltar");
	        return true;
	    }
	    case 32:
	    {
	        new info[1024];
	        format(info, sizeof(info), "Permitir que jogadores cliquem nesta textdraw?\n\nStatus atual: %s\n\n{FFFF00}Para a Textdraw funcionar, ative um alinhamento.", tData[pData[playerid][P_CurrentTextdraw]][T_Selectable] ? ("ATIVADO") : ("DESATIVADO"));
	        
	        ShowPlayerDialog(playerid, dialogid+1574, DIALOG_STYLE_MSGBOX, CreateDialogTitle(playerid, "Seleção da Textdraw"), info, "Ativar", "Desativar");
	        return true;
	    }
	    case 33:
	    {
	        if(GetPVarInt(playerid, "Use2DTD") == 1)
			{
				new info[256];
				info = "O que voce quer configurar no modelo 3D?\n\n";
				format(info, sizeof(info), "%sEscolher Modelo 3D\n", info);
				format(info, sizeof(info), "%sRotacao Horizontal (X)\n", info);
				format(info, sizeof(info), "%sRotacao Vertical (Y)\n", info);
				format(info, sizeof(info), "%sRotacao Lateral (Z)\n", info);
				format(info, sizeof(info), "%sZoom do Modelo", info);
				ShowPlayerDialog(playerid, dialogid+1574, DIALOG_STYLE_LIST, CreateDialogTitle(playerid, "Modelo 3D da Textdraw"), info, "Aceitar", "Cancelar");
			}
	        else if(!GetPVarInt(playerid, "Use2DTD"))
			{
				SendClientMessage(playerid, -1, "Voce precisa selecionar a Fonte #5 para usar modelos 3D");
				ShowTextDrawDialog(playerid, 5);
			}
	        return true;
	    }
	    case 34:
	    {
	        ShowPlayerDialog(playerid, dialogid+1574, DIALOG_STYLE_INPUT, CreateDialogTitle(playerid, "Modelo 3D da Textdraw"), "Digite o ID do modelo 3D que voce quer mostrar:", "Aceitar", "Cancelar");
	        return true;
	    }
	    case 35:
	    {
	        ShowPlayerDialog(playerid, dialogid+1574, DIALOG_STYLE_INPUT, CreateDialogTitle(playerid, "Rotacao Horizontal (X)"), "Digite a rotacao horizontal do modelo:", "Ir", "Voltar");
	        return true;
	    }
	    case 36:
	    {
	        ShowPlayerDialog(playerid, dialogid+1574, DIALOG_STYLE_INPUT, CreateDialogTitle(playerid, "Rotacao Vertical (Y)"), "Digite a rotacao vertical do modelo:", "Ir", "Voltar");
	        return true;
	    }
	    case 37:
	    {
	        ShowPlayerDialog(playerid, dialogid+1574, DIALOG_STYLE_INPUT, CreateDialogTitle(playerid, "Rotacao Lateral (Z)"), "Digite a rotacao lateral do modelo:", "Ir", "Voltar");
	        return true;
	    }
	    case 38:
	    {
	        ShowPlayerDialog(playerid, dialogid+1574, DIALOG_STYLE_INPUT, CreateDialogTitle(playerid, "Zoom do Modelo"), "Digite o zoom do modelo (1.0 = tamanho normal):", "Ir", "Voltar");
	        return true;
	    }
	    // Color utilities (search/group/sort/recents and alpha selection)
	    case 40:
	    {
	        new info[256];
	        info = "Digite parte do nome em PT ou HEX (#RRGGBB) para filtrar:";
	        ShowPlayerDialog(playerid, dialogid+1574, DIALOG_STYLE_INPUT, CreateDialogTitle(playerid, "Buscar cor"), info, "Buscar", "Voltar");
	        return true;
	    }
	    case 41:
	    {
	        new info[256];
	        info = "Escolha uma familia de cores:\n\n";
	        format(info, sizeof(info), "%sTodas\n", info);
	        format(info, sizeof(info), "%sBrancos/Cinzas\n", info);
	        format(info, sizeof(info), "%sAzuis\n", info);
	        format(info, sizeof(info), "%sVerdes\n", info);
	        format(info, sizeof(info), "%sAmarelos/Dourados\n", info);
	        format(info, sizeof(info), "%sMarrons/Laranjas\n", info);
	        format(info, sizeof(info), "%sVermelhos/Rosas\n", info);
	        format(info, sizeof(info), "%sRoxos/Violetas", info);
	        ShowPlayerDialog(playerid, dialogid+1574, DIALOG_STYLE_LIST, CreateDialogTitle(playerid, "Familia de cores"), info, "OK", "Voltar");
	        return true;
	    }
	    case 42:
	    {
	        new info[128];
	        format(info, sizeof(info), "Modo atual: %s\n\nPadrao\nAlfabetica (PT)", pData[playerid][P_ColorSortMode] ? ("ALFABETICA") : ("PADRAO"));
	        ShowPlayerDialog(playerid, dialogid+1574, DIALOG_STYLE_LIST, CreateDialogTitle(playerid, "Ordenar cores"), info, "OK", "Voltar");
	        return true;
	    }
	    case 43:
	    {
	        new info[512];
	        info = "Recentes:\n";
	        new shown;
	        for(new r = 0; r < pData[playerid][P_RecentCount] && r < 10; r++)
	        {
	            new idx = pData[playerid][P_RecentColors][r];
	            if(idx >= 0 && idx < sizeof(HTML_COLORS))
	            {
	                new hexstr[8];
	                format(hexstr, sizeof(hexstr), "%s", HTML_COLORS[idx][HTMLColorHex]);
	                format(info, sizeof(info), "%s{%c%c%c%c%c%c}%s{FFFFFF} - %s\n", info, hexstr[1], hexstr[2], hexstr[3], hexstr[4], hexstr[5], hexstr[6], HTML_COLOR_NAMES_PT[idx], HTML_COLORS[idx][HTMLColorHex]);
	                shown++;
	            }
	        }
	        if(!shown) format(info, sizeof(info), "%s(nenhum)\n", info);
	        ShowPlayerDialog(playerid, dialogid+1574, DIALOG_STYLE_LIST, CreateDialogTitle(playerid, "Recentes"), info, "OK", "Voltar");
	        return true;
	    }
	    case 44:
	    {
	        new info[160];
	        info = "Selecione a transparencia (alpha):\n\n100% (255)\n75% (191)\n50% (127)\n25% (63)\nPersonalizar\nAlternar favorito";
	        ShowPlayerDialog(playerid, dialogid+1574, DIALOG_STYLE_LIST, CreateDialogTitle(playerid, "Transparencia"), info, "OK", "Voltar");
	        return true;
	    }
	    case 45:
	    {
	        new info[128];
	        info = "Digite o alpha (0-255):";
	        ShowPlayerDialog(playerid, dialogid+1574, DIALOG_STYLE_INPUT, CreateDialogTitle(playerid, "Transparencia"), info, "OK", "Voltar");
	        return true;
	    }
	}
	return false;
}

stock CreateDialogTitle( playerid, text[] )
{
    /*	Creates a default title for the dialogs.
        @playerid:      ID of the player getting his dialog title generated.
	    @text[]:	    Text to be attached to the title.
	*/
	#pragma unused playerid
	
	new string[128];
	if(!strlen(CurrentProject) || !strcmp(CurrentProject, " "))
		format(string, sizeof(string), "qlala-zamaroths Textdraw: %s", text);
	else
	    format(string, sizeof(string), "%s - qlala-zamaroths Textdraw: %s", CurrentProject, text);
	return string;
}
stock ResetPlayerVars( playerid )
{
	/*	Resets a specific player's pData info.
	    @playerid:      ID of the player to reset the data of.
	*/
	
	pData[playerid][P_Editing] = false;
	strmid(CurrentProject, "", 0, 1, 128);
    if(pData[playerid][P_ClickTestMode])
    {
        pData[playerid][P_ClickTestMode] = false;
        CancelSelectTextDraw(playerid);
    }
	// Reset color UI state
	pData[playerid][P_ColorPageStart] = 0;
	pData[playerid][P_ColorFilter][0] = '\0';
	pData[playerid][P_ColorSortMode] = 0;
	pData[playerid][P_ColorGroup] = 0;
	pData[playerid][P_RecentCount] = 0;
	pData[playerid][P_PendingColorIndex] = -1;
	pData[playerid][P_ColorAlpha] = 255;
	// Reset favorites state
	pData[playerid][P_FavoriteCount] = 0;
	for(new i = 0; i < 20; i++) pData[playerid][P_Favorites][i] = -1;
	// Reset click-area overlay state
	HideClickAreaOverlay(playerid);
	pData[playerid][P_ClickAreaOverlayEnabled] = false;
	pData[playerid][P_ClickAreaOverlay] = INVALID_PLAYER_TEXT_DRAW;
	pData[playerid][P_ClickGuideW] = INVALID_PLAYER_TEXT_DRAW;
	pData[playerid][P_ClickGuideH] = INVALID_PLAYER_TEXT_DRAW;
	// Default selection color (green)
	pData[playerid][P_SelectColor] = 0xAA00FF00;
}

forward KeyEdit( playerid );
public KeyEdit( playerid )
{
	/*  Handles the edition by keyboard.
		@playerid:          	Player editing.
	*/
	if(pData[playerid][P_KeyEdition] == EDIT_NONE) return 0;
	
	new string[256]; // Buffer for all gametexts and other messages.
	new keys, updown, leftright;
	GetPlayerKeys(playerid, keys, updown, leftright);

	if(updown < 0) // He's pressing up
	{
	    switch(pData[playerid][P_KeyEdition])
	    {
	        case EDIT_POSITION:
	        {
				if(keys == KEY_SPRINT)	tData[pData[playerid][P_CurrentTextdraw]][T_Y] -= 10.0;
				else if(keys == KEY_WALK)tData[pData[playerid][P_CurrentTextdraw]][T_Y] -= 0.1;
				else                    tData[pData[playerid][P_CurrentTextdraw]][T_Y] -= 1.0;

				format(string, sizeof(string), "~n~~n~~n~~n~~n~~n~~n~~n~~n~~n~~y~~h~Position: ~b~X: ~w~%.4f ~r~- ~b~Y: ~w~%.4f", \
			        tData[pData[playerid][P_CurrentTextdraw]][T_X], tData[pData[playerid][P_CurrentTextdraw]][T_Y]);
	        }
	        
	        case EDIT_SIZE:
	        {
	            if(keys == KEY_SPRINT)	tData[pData[playerid][P_CurrentTextdraw]][T_YSize] -= 1.0;
	            else if(keys == KEY_WALK)	tData[pData[playerid][P_CurrentTextdraw]][T_YSize] -= 0.01;
				else                    tData[pData[playerid][P_CurrentTextdraw]][T_YSize] -= 0.1;

				format(string, sizeof(string), "~n~~n~~n~~n~~n~~n~~n~~n~~n~~n~~y~~h~Size: ~b~X: ~w~%.4f ~r~- ~b~Y: ~w~%.4f", \
			        tData[pData[playerid][P_CurrentTextdraw]][T_XSize], tData[pData[playerid][P_CurrentTextdraw]][T_YSize]);
	        }
	        
	        case EDIT_BOX:
	        {
	            if(keys == KEY_SPRINT)	tData[pData[playerid][P_CurrentTextdraw]][T_TextSizeY] -= 10.0;
	            else if(keys == KEY_WALK)	tData[pData[playerid][P_CurrentTextdraw]][T_TextSizeY] -= 0.1;
				else                    tData[pData[playerid][P_CurrentTextdraw]][T_TextSizeY] -= 1.0;

				format(string, sizeof(string), "~n~~n~~n~~n~~n~~n~~n~~n~~n~~n~~y~~h~Size: ~b~X: ~w~%.4f ~r~- ~b~Y: ~w~%.4f", \
			        tData[pData[playerid][P_CurrentTextdraw]][T_TextSizeX], tData[pData[playerid][P_CurrentTextdraw]][T_TextSizeY]);
	        }
	    }
	}
	else if(updown > 0) // He's pressing down
	{
	    switch(pData[playerid][P_KeyEdition])
	    {
	        case EDIT_POSITION:
	        {
                if(keys == KEY_SPRINT)	tData[pData[playerid][P_CurrentTextdraw]][T_Y] += 10.0;
                else if(keys == KEY_WALK)	tData[pData[playerid][P_CurrentTextdraw]][T_Y] += 0.1;
				else                    tData[pData[playerid][P_CurrentTextdraw]][T_Y] += 1.0;

				format(string, sizeof(string), "~n~~n~~n~~n~~n~~n~~n~~n~~n~~n~~y~~h~Position: ~b~X: ~w~%.4f ~r~- ~b~Y: ~w~%.4f", \
			        tData[pData[playerid][P_CurrentTextdraw]][T_X], tData[pData[playerid][P_CurrentTextdraw]][T_Y]);
	        }
	        
	        case EDIT_SIZE:
	        {
	            if(keys == KEY_SPRINT)	tData[pData[playerid][P_CurrentTextdraw]][T_YSize] += 1.0;
	            else if(keys == KEY_WALK)	tData[pData[playerid][P_CurrentTextdraw]][T_YSize] += 0.01;
				else                    tData[pData[playerid][P_CurrentTextdraw]][T_YSize] += 0.1;

				format(string, sizeof(string), "~n~~n~~n~~n~~n~~n~~n~~n~~n~~n~~y~~h~Size: ~b~X: ~w~%.4f ~r~- ~b~Y: ~w~%.4f", \
			        tData[pData[playerid][P_CurrentTextdraw]][T_XSize], tData[pData[playerid][P_CurrentTextdraw]][T_YSize]);
	        }
	        
	        case EDIT_BOX:
	        {
	            if(keys == KEY_SPRINT)	tData[pData[playerid][P_CurrentTextdraw]][T_TextSizeY] += 10.0;
	            else if(keys == KEY_WALK)	tData[pData[playerid][P_CurrentTextdraw]][T_TextSizeY] += 0.1;
				else                    tData[pData[playerid][P_CurrentTextdraw]][T_TextSizeY] += 1.0;

				format(string, sizeof(string), "~n~~n~~n~~n~~n~~n~~n~~n~~n~~n~~y~~h~Size: ~b~X: ~w~%.4f ~r~- ~b~Y: ~w~%.4f", \
			        tData[pData[playerid][P_CurrentTextdraw]][T_TextSizeX], tData[pData[playerid][P_CurrentTextdraw]][T_TextSizeY]);
	        }
	    }
	}

	if(leftright < 0) // He's pressing left
	{
        switch(pData[playerid][P_KeyEdition])
	    {
	        case EDIT_POSITION:
	        {
                if(keys == KEY_SPRINT)	tData[pData[playerid][P_CurrentTextdraw]][T_X] -= 10.0;
                else if(keys == KEY_WALK)	tData[pData[playerid][P_CurrentTextdraw]][T_X] -= 0.1;
				else                    tData[pData[playerid][P_CurrentTextdraw]][T_X] -= 1.0;

				format(string, sizeof(string), "~n~~n~~n~~n~~n~~n~~n~~n~~n~~n~~y~~h~Position: ~b~X: ~w~%.4f ~r~- ~b~Y: ~w~%.4f", \
			        tData[pData[playerid][P_CurrentTextdraw]][T_X], tData[pData[playerid][P_CurrentTextdraw]][T_Y]);
	        }
	        
	        case EDIT_SIZE:
	        {
	            if(keys == KEY_SPRINT)	tData[pData[playerid][P_CurrentTextdraw]][T_XSize] -= 0.1;
	            else if(keys == KEY_WALK)	tData[pData[playerid][P_CurrentTextdraw]][T_XSize] -= 0.001;
				else                    tData[pData[playerid][P_CurrentTextdraw]][T_XSize] -= 0.01;

				format(string, sizeof(string), "~n~~n~~n~~n~~n~~n~~n~~n~~n~~n~~y~~h~Size: ~b~X: ~w~%.4f ~r~- ~b~Y: ~w~%.4f", \
			        tData[pData[playerid][P_CurrentTextdraw]][T_XSize], tData[pData[playerid][P_CurrentTextdraw]][T_YSize]);
	        }
	        
	        case EDIT_BOX:
	        {
	            if(keys == KEY_SPRINT)	tData[pData[playerid][P_CurrentTextdraw]][T_TextSizeX] -= 10.0;
	            else if(keys == KEY_WALK)	tData[pData[playerid][P_CurrentTextdraw]][T_TextSizeX] -= 0.1;
				else                    tData[pData[playerid][P_CurrentTextdraw]][T_TextSizeX] -= 1.0;

				format(string, sizeof(string), "~n~~n~~n~~n~~n~~n~~n~~n~~n~~n~~y~~h~Size: ~b~X: ~w~%.4f ~r~- ~b~Y: ~w~%.4f", \
			        tData[pData[playerid][P_CurrentTextdraw]][T_TextSizeX], tData[pData[playerid][P_CurrentTextdraw]][T_TextSizeY]);
	        }
	    }
	}
	else if(leftright > 0) // He's pressing right
	{
        switch(pData[playerid][P_KeyEdition])
	    {
	        case EDIT_POSITION:
	        {
                if(keys == KEY_SPRINT)	tData[pData[playerid][P_CurrentTextdraw]][T_X] += 10.0;
                else if(keys == KEY_WALK)	tData[pData[playerid][P_CurrentTextdraw]][T_X] += 0.1;
				else                    tData[pData[playerid][P_CurrentTextdraw]][T_X] += 1.0;

				format(string, sizeof(string), "~n~~n~~n~~n~~n~~n~~n~~n~~n~~n~~y~~h~Position: ~b~X: ~w~%.4f ~r~- ~b~Y: ~w~%.4f", \
			        tData[pData[playerid][P_CurrentTextdraw]][T_X], tData[pData[playerid][P_CurrentTextdraw]][T_Y]);
	        }
	        
	        case EDIT_SIZE:
	        {
	            if(keys == KEY_SPRINT)	tData[pData[playerid][P_CurrentTextdraw]][T_XSize] += 0.1;
	            else if(keys == KEY_WALK)	tData[pData[playerid][P_CurrentTextdraw]][T_XSize] += 0.001;
				else                    tData[pData[playerid][P_CurrentTextdraw]][T_XSize] += 0.01;

				format(string, sizeof(string), "~n~~n~~n~~n~~n~~n~~n~~n~~n~~n~~y~~h~Size: ~b~X: ~w~%.4f ~r~- ~b~Y: ~w~%.4f", \
			        tData[pData[playerid][P_CurrentTextdraw]][T_XSize], tData[pData[playerid][P_CurrentTextdraw]][T_YSize]);
	        }
	        
	        case EDIT_BOX:
	        {
	            if(keys == KEY_SPRINT)	tData[pData[playerid][P_CurrentTextdraw]][T_TextSizeX] += 10.0;
	            else if(keys == KEY_WALK)	tData[pData[playerid][P_CurrentTextdraw]][T_TextSizeX] += 0.1;
				else                    tData[pData[playerid][P_CurrentTextdraw]][T_TextSizeX] += 1.0;

				format(string, sizeof(string), "~n~~n~~n~~n~~n~~n~~n~~n~~n~~n~~y~~h~Size: ~b~X: ~w~%.4f ~r~- ~b~Y: ~w~%.4f", \
			        tData[pData[playerid][P_CurrentTextdraw]][T_TextSizeX], tData[pData[playerid][P_CurrentTextdraw]][T_TextSizeY]);
	        }
	    }
	}

	GameTextForPlayer(playerid, string, 999999999, 3);
	UpdateTextdraw(pData[playerid][P_CurrentTextdraw]);
	if(pData[playerid][P_ClickAreaOverlayEnabled] && (pData[playerid][P_KeyEdition] == EDIT_BOX || pData[playerid][P_KeyEdition] == EDIT_POSITION))
	{
		RebuildClickAreaOverlay(playerid);
	}
	if(pData[playerid][P_KeyEdition] == EDIT_POSITION)
	{
		SaveTDData(pData[playerid][P_CurrentTextdraw], "T_X");
		SaveTDData(pData[playerid][P_CurrentTextdraw], "T_Y");
	}
	else if(pData[playerid][P_KeyEdition] == EDIT_SIZE)
	{
		SaveTDData(pData[playerid][P_CurrentTextdraw], "T_XSize");
		SaveTDData(pData[playerid][P_CurrentTextdraw], "T_YSize");
	}
	else if(pData[playerid][P_KeyEdition] == EDIT_BOX)
	{
		SaveTDData(pData[playerid][P_CurrentTextdraw], "T_TextSizeX");
		SaveTDData(pData[playerid][P_CurrentTextdraw], "T_TextSizeY");
	}
	SetTimerEx("KeyEdit", 100, 0, "i", playerid);
	return 1;
}

public OnPlayerKeyStateChange( playerid, newkeys, oldkeys )
{
    if(pData[playerid][P_KeyEdition] != EDIT_NONE && newkeys == KEY_SECONDARY_ATTACK)
	{
	    GameTextForPlayer(playerid, " ", 100, 3);
	    TogglePlayerControllable(playerid, 1);

        new string[128];
	    switch(pData[playerid][P_KeyEdition])
	    {
	        			case EDIT_POSITION:
			{
				format(string, sizeof(string), "Textdraw #%d movida com sucesso.", pData[playerid][P_CurrentTextdraw]);
			}
			case EDIT_SIZE:
			{
				format(string, sizeof(string), "Textdraw #%d redimensionada com sucesso.", pData[playerid][P_CurrentTextdraw]);
			}
			case EDIT_BOX:
			{
				format(string, sizeof(string), "Área de clique da Textdraw #%d redimensionada com sucesso.", pData[playerid][P_CurrentTextdraw]);
			}
	    }

        if(pData[playerid][P_KeyEdition] == EDIT_BOX)   SetTimerEx("ShowTextDrawDialogEx", 500, 0, "ii", playerid, 5);
		else 											SetTimerEx("ShowTextDrawDialogEx", 500, 0, "ii", playerid, 5);
	    SendClientMessage(playerid, MSG_COLOR, string);
	    pData[playerid][P_KeyEdition] = EDIT_NONE;
	}
	return 1;
}

stock CreateNewProject( name[] )
{
    /*	Creates a new .tde project file.
	    @name[]:		Name to be used in the filename.
	*/

	new string[128], File:File;

	// Add it to the list.
	format(string, sizeof(string), "%s\r\n", name);
	File = fopen("tdlist.lst", io_append);
	fwrite(File, string);
	fclose(File);

	// Create the default file.
	File = fopen(name, io_write);
	fwrite(File, "TDFile=yes");
	fclose(File);
}

stock ClearTextdraw( tdid )
{
	/*	Resets a textdraw's variables and destroys it.
	    @tdid:          Textdraw ID
	*/
	TextDrawHideForAll(tData[tdid][T_Handler]);
	tData[tdid][T_Created] = false;
	strmid(tData[tdid][T_Text], "", 0, 1, 2);
    tData[tdid][T_X] = 0.0;
    tData[tdid][T_Y] = 0.0;
    tData[tdid][T_Alignment] = 0;
    tData[tdid][T_BackColor] = 0;
    tData[tdid][T_UseBox] = 0;
    tData[tdid][T_BoxColor] = 0;
    tData[tdid][T_TextSizeX] = 0.0;
    tData[tdid][T_TextSizeY] = 0.0;
    tData[tdid][T_Color] = 0;
    tData[tdid][T_Font] = 0;
    tData[tdid][T_XSize] = 0.0;
    tData[tdid][T_YSize] = 0.0;
    tData[tdid][T_Outline] = 0;
    tData[tdid][T_Proportional] = 0;
    tData[tdid][T_Shadow] = 0;
    tData[tdid][T_Selectable] = 0;
    tData[tdid][T_PreviewModel] = -1;
	tData[tdid][PMZoom] = 0;
	tData[tdid][PMRotX] = 0;
	tData[tdid][PMRotY] = 0.0;
	tData[tdid][PMRotZ] = 0;
}
stock CreateDefaultTextdraw( tdid, save = 1 )
{
	/*  Creates a new textdraw with default settings.
		@tdid:          Textdraw ID
	*/
	tData[tdid][T_Created] = true;
	format(tData[tdid][T_Text], 1024, "New Textdraw", 1);
    tData[tdid][T_X] = 250.0;
    tData[tdid][T_Y] = 10.0;
    tData[tdid][T_Alignment] = 0;
    tData[tdid][T_BackColor] = RGB(0, 0, 0, 255);
    tData[tdid][T_UseBox] = 0;
    tData[tdid][T_BoxColor] = RGB(0, 0, 0, 255);
    tData[tdid][T_TextSizeX] = 0.0;
    tData[tdid][T_TextSizeY] = 0.0;
    tData[tdid][T_Color] = RGB(255, 255, 255, 255);
    tData[tdid][T_Font] = 1;
    tData[tdid][T_XSize] = 0.5;
    tData[tdid][T_YSize] = 1.0;
    tData[tdid][T_Outline] = 0;
    tData[tdid][T_Proportional] = 1;
    tData[tdid][T_Shadow] = 1;
    tData[tdid][T_Selectable] = 0;
    tData[tdid][T_Mode] = 0;
    tData[tdid][T_PreviewModel] = -1;
	tData[tdid][PMZoom] = 1.0;
	tData[tdid][PMRotX] = -16.0;
	tData[tdid][PMRotY] = 0.0;
	tData[tdid][PMRotZ] = -55.0;
	
    UpdateTextdraw(tdid);
    if(save) SaveTDData(tdid, "T_Created");
}
stock DuplicateTextdraw( source, to )
{
	/*  Duplicates a textdraw from another one. Updates the new one.
	    @source:            Where to copy the textdraw from.
	    @to:                Where to copy the textdraw to.
	*/
	tData[to][T_Created] = tData[source][T_Created];
	format(tData[to][T_Text], 1024, "%s", tData[source][T_Text]);
    tData[to][T_X] = tData[source][T_X];
    tData[to][T_Y] = tData[source][T_Y];
    tData[to][T_Alignment] = tData[source][T_Alignment];
    tData[to][T_BackColor] = tData[source][T_BackColor];
    tData[to][T_UseBox] = tData[source][T_UseBox];
    tData[to][T_BoxColor] = tData[source][T_BoxColor];
    tData[to][T_TextSizeX] = tData[source][T_TextSizeX];
    tData[to][T_TextSizeY] = tData[source][T_TextSizeY];
    tData[to][T_Color] = tData[source][T_Color];
    tData[to][T_Font] = tData[source][T_Font];
    tData[to][T_XSize] = tData[source][T_XSize];
    tData[to][T_YSize] = tData[source][T_YSize];
    tData[to][T_Outline] = tData[source][T_Outline];
    tData[to][T_Proportional] = tData[source][T_Proportional];
    tData[to][T_Shadow] = tData[source][T_Shadow];
    tData[to][T_Selectable] = tData[source][T_Selectable];
    tData[to][T_Mode] = tData[source][T_Mode];
    tData[to][T_PreviewModel] = tData[source][T_PreviewModel];
    tData[to][PMRotX] = tData[source][PMRotX];
    tData[to][PMRotY] = tData[source][PMRotY];
    tData[to][PMRotZ] = tData[source][PMRotZ];
    tData[to][PMZoom] = tData[source][PMZoom];
	
	UpdateTextdraw(to);
	SaveTDData(to, "T_Created");
	SaveTDData(to, "T_Text");
	SaveTDData(to, "T_X");
	SaveTDData(to, "T_Y");
	SaveTDData(to, "T_Alignment");
	SaveTDData(to, "T_BackColor");
	SaveTDData(to, "T_UseBox");
	SaveTDData(to, "T_BoxColor");
    SaveTDData(to, "T_TextSizeX");
    SaveTDData(to, "T_TextSizeY");
    SaveTDData(to, "T_Color");
    SaveTDData(to, "T_Font");
    SaveTDData(to, "T_XSize");
    SaveTDData(to, "T_YSize");
    SaveTDData(to, "T_Outline");
    SaveTDData(to, "T_Proportional");
    SaveTDData(to, "T_Shadow");
    SaveTDData(to, "T_Selectable");
    SaveTDData(to, "T_Mode");
    SaveTDData(to, "T_PreviewModel");
    SaveTDData(to, "PMRotX");
    SaveTDData(to, "PMRotY");
    SaveTDData(to, "PMRotZ");
    SaveTDData(to, "PMZoom");
}

stock UpdateTextdraw( tdid )
{
	if(!tData[tdid][T_Created]) return false;
	TextDrawHideForAll(tData[tdid][T_Handler]);
	TextDrawDestroy(tData[tdid][T_Handler]);
	
	// Recreate it
	tData[tdid][T_Handler] = TextDrawCreate(tData[tdid][T_X], tData[tdid][T_Y], tData[tdid][T_Text]);
	if(tData[tdid][T_Alignment] != 0)
		TextDrawAlignment(tData[tdid][T_Handler], tData[tdid][T_Alignment]);
	TextDrawBackgroundColor(tData[tdid][T_Handler], tData[tdid][T_BackColor]);
	TextDrawColor(tData[tdid][T_Handler], tData[tdid][T_Color]);
	TextDrawFont(tData[tdid][T_Handler], tData[tdid][T_Font]);
	TextDrawLetterSize(tData[tdid][T_Handler], tData[tdid][T_XSize], tData[tdid][T_YSize]);
	TextDrawSetOutline(tData[tdid][T_Handler], tData[tdid][T_Outline]);
	TextDrawSetProportional(tData[tdid][T_Handler], tData[tdid][T_Proportional]);
	TextDrawSetShadow(tData[tdid][T_Handler], tData[tdid][T_Shadow]);
	TextDrawSetSelectable(tData[tdid][T_Handler], tData[tdid][T_Selectable]);
	if(tData[tdid][T_PreviewModel] > -1)
	{
	    TextDrawSetPreviewModel(tData[tdid][T_Handler], tData[tdid][T_PreviewModel]);
	    TextDrawSetPreviewRot(tData[tdid][T_Handler], tData[tdid][PMRotX], tData[tdid][PMRotY], tData[tdid][PMRotZ], tData[tdid][PMZoom]);
	}
	// Always apply click area for hit detection; box visuals only if enabled
	TextDrawTextSize(tData[tdid][T_Handler], tData[tdid][T_TextSizeX], tData[tdid][T_TextSizeY]);
	if(tData[tdid][T_UseBox])
	{
		TextDrawUseBox(tData[tdid][T_Handler], tData[tdid][T_UseBox]);
		TextDrawBoxColor(tData[tdid][T_Handler], tData[tdid][T_BoxColor]);
	}
	TextDrawShowForAll(tData[tdid][T_Handler]);
	return true;
}

stock DeleteTDFromFile( tdid )
{
    /*  Deletes a specific textdraw from its .tde file
	    @tdid:              Textdraw ID.
	*/
	new string[128], filename[135];
	format(filename, sizeof(filename), "%s.tde", CurrentProject);
	
	format(string, sizeof(string), "%dT_Created", tdid);
	dini_Unset(filename, string);
	format(string, sizeof(string), "%dT_Text", tdid);
	dini_Unset(filename, string);
	format(string, sizeof(string), "%dT_X", tdid);
	dini_Unset(filename, string);
	format(string, sizeof(string), "%dT_Y", tdid);
	dini_Unset(filename, string);
	format(string, sizeof(string), "%dT_Alignment", tdid);
	dini_Unset(filename, string);
	format(string, sizeof(string), "%dT_BackColor", tdid);
	dini_Unset(filename, string);
	format(string, sizeof(string), "%dT_UseBox", tdid);
	dini_Unset(filename, string);
	format(string, sizeof(string), "%dT_BoxColor", tdid);
	dini_Unset(filename, string);
	format(string, sizeof(string), "%dT_TextSizeX", tdid);
	dini_Unset(filename, string);
	format(string, sizeof(string), "%dT_TextSizeY", tdid);
	dini_Unset(filename, string);
	format(string, sizeof(string), "%dT_Color", tdid);
	dini_Unset(filename, string);
	format(string, sizeof(string), "%dT_Font", tdid);
	dini_Unset(filename, string);
	format(string, sizeof(string), "%dT_XSize", tdid);
	dini_Unset(filename, string);
	format(string, sizeof(string), "%dT_YSize", tdid);
	dini_Unset(filename, string);
	format(string, sizeof(string), "%dT_Outline", tdid);
	dini_Unset(filename, string);
	format(string, sizeof(string), "%dT_Proportional", tdid);
	dini_Unset(filename, string);
	format(string, sizeof(string), "%dT_Shadow", tdid);
	dini_Unset(filename, string);
	format(string, sizeof(string), "%dT_Selectable", tdid);
	dini_Unset(filename, string);
	format(string, sizeof(string), "%dT_Mode", tdid);
	dini_Unset(filename, string);
	format(string, sizeof(string), "%dT_PreviewModel", tdid);
	dini_Unset(filename, string);
	format(string, sizeof(string), "%dPMRotX", tdid);
	dini_Unset(filename, string);
	format(string, sizeof(string), "%dPMRotY", tdid);
	dini_Unset(filename, string);
	format(string, sizeof(string), "%dPMRotZ", tdid);
	dini_Unset(filename, string);
	format(string, sizeof(string), "%dPMZoom", tdid);
	dini_Unset(filename, string);
}

stock SaveTDData( tdid, data[] )
{
	/*  Saves a specific data from a specific textdraw to project file.
	    @tdid:              Textdraw ID.
	    @data[]:            Data to be saved.
	*/
	new string[128], filename[135];
	format(string, sizeof(string), "%d%s", tdid, data);
	format(filename, sizeof(filename), "%s.tde", CurrentProject);
	
	if(!strcmp("T_Created", data))
        dini_IntSet(filename, string, 1);
	else if(!strcmp("T_Text", data))
		dini_Set(filename, string, tData[tdid][T_Text]);
	else if(!strcmp("T_X", data))
		dini_FloatSet(filename, string, tData[tdid][T_X]);
	else if(!strcmp("T_Y", data))
		dini_FloatSet(filename, string, tData[tdid][T_Y]);
	else if(!strcmp("T_Alignment", data))
		dini_IntSet(filename, string, tData[tdid][T_Alignment]);
	else if(!strcmp("T_BackColor", data))
	{
		dini_IntSet(filename, string, tData[tdid][T_BackColor]);
		// Mark file as using ARGB colors
		dini_Set(filename, "ColorFormat", "ARGB");
	}
	else if(!strcmp("T_UseBox", data))
		dini_IntSet(filename, string, tData[tdid][T_UseBox]);
	else if(!strcmp("T_BoxColor", data))
	{
		dini_IntSet(filename, string, tData[tdid][T_BoxColor]);
		dini_Set(filename, "ColorFormat", "ARGB");
	}
    else if(!strcmp("T_TextSizeX", data))
		dini_FloatSet(filename, string, tData[tdid][T_TextSizeX]);
    else if(!strcmp("T_TextSizeY", data))
		dini_FloatSet(filename, string, tData[tdid][T_TextSizeY]);
    else if(!strcmp("T_Color", data))
	{
		dini_IntSet(filename, string, tData[tdid][T_Color]);
		dini_Set(filename, "ColorFormat", "ARGB");
	}
    else if(!strcmp("T_Font", data))
		dini_IntSet(filename, string, tData[tdid][T_Font]);
    else if(!strcmp("T_XSize", data))
		dini_FloatSet(filename, string, tData[tdid][T_XSize]);
    else if(!strcmp("T_YSize", data))
		dini_FloatSet(filename, string, tData[tdid][T_YSize]);
    else if(!strcmp("T_Outline", data))
		dini_IntSet(filename, string, tData[tdid][T_Outline]);
    else if(!strcmp("T_Proportional", data))
		dini_IntSet(filename, string, tData[tdid][T_Proportional]);
    else if(!strcmp("T_Shadow", data))
		dini_IntSet(filename, string, tData[tdid][T_Shadow]);
    else if(!strcmp("T_Selectable", data))
		dini_IntSet(filename, string, tData[tdid][T_Selectable]);
    else if(!strcmp("T_Mode", data))
		dini_IntSet(filename, string, tData[tdid][T_Mode]);
    else if(!strcmp("T_PreviewModel", data))
		dini_IntSet(filename, string, tData[tdid][T_PreviewModel]);
    else if(!strcmp("PMRotX", data))
		dini_FloatSet(filename, string, tData[tdid][PMRotX]);
    else if(!strcmp("PMRotY", data))
		dini_FloatSet(filename, string, tData[tdid][PMRotY]);
    else if(!strcmp("PMRotZ", data))
		dini_FloatSet(filename, string, tData[tdid][PMRotZ]);
    else if(!strcmp("PMZoom", data))
		dini_FloatSet(filename, string, tData[tdid][PMZoom]);
	else
	    SendClientMessageToAll(MSG_COLOR, "Incorrect data parsed, textdraw autosave failed");
}

stock LoadProject( playerid, filename[] )
{
	/*  Loads a project for edition.
	    @filename[]:            Filename where the project is currently saved.
	*/
	new string[128];
	if(!dini_Isset(filename, "TDFile"))
	{
	    SendClientMessage(playerid, MSG_COLOR, "Arquivo de textdraw inválido.");
	    ShowTextDrawDialog(playerid, 0);
	}
	else
	{
		new bool:isARGB = false;
		if(dini_Isset(filename, "ColorFormat"))
		{
			new fmt[16];
			format(fmt, sizeof(fmt), "%s", dini_Get(filename, "ColorFormat"));
			if(!strcmp(fmt, "ARGB", true)) isARGB = true;
		}
		for(new i; i < MAX_TEXTDRAWS; i ++)
		{
		    format(string, sizeof(string), "%dT_Created", i);
		    if(dini_Isset(filename, string))
		    {
		        CreateDefaultTextdraw(i, 0); // Create but don't save.

		        format(string, sizeof(string), "%dT_Text", i);
		        if(dini_Isset(filename, string))
					format(tData[i][T_Text], 1536, "%s", dini_Get(filename, string));

		        format(string, sizeof(string), "%dT_X", i);
				if(dini_Isset(filename, string))
					tData[i][T_X] = dini_Float(filename, string);

		        format(string, sizeof(string), "%dT_Y", i);
				if(dini_Isset(filename, string))
					tData[i][T_Y] = dini_Float(filename, string);

		        format(string, sizeof(string), "%dT_Alignment", i);
				if(dini_Isset(filename, string))
					tData[i][T_Alignment] = dini_Int(filename, string);

		        format(string, sizeof(string), "%dT_BackColor", i);
				if(dini_Isset(filename, string))
					tData[i][T_BackColor] = dini_Int(filename, string);

		        format(string, sizeof(string), "%dT_UseBox", i);
				if(dini_Isset(filename, string))
					tData[i][T_UseBox] = dini_Int(filename, string);

		        format(string, sizeof(string), "%dT_BoxColor", i);
				if(dini_Isset(filename, string))
					tData[i][T_BoxColor] = dini_Int(filename, string);

		        format(string, sizeof(string), "%dT_TextSizeX", i);
		    	if(dini_Isset(filename, string))
					tData[i][T_TextSizeX] = dini_Float(filename, string);

		        format(string, sizeof(string), "%dT_TextSizeY", i);
		    	if(dini_Isset(filename, string))
					tData[i][T_TextSizeY] = dini_Float(filename, string);

		        format(string, sizeof(string), "%dT_Color", i);
		    	if(dini_Isset(filename, string))
					tData[i][T_Color] = dini_Int(filename, string);

		        format(string, sizeof(string), "%dT_Font", i);
		    	if(dini_Isset(filename, string))
					tData[i][T_Font] = dini_Int(filename, string);

		        format(string, sizeof(string), "%dT_XSize", i);
				if(dini_Isset(filename, string))
					tData[i][T_XSize] = dini_Float(filename, string);

		        format(string, sizeof(string), "%dT_YSize", i);
				if(dini_Isset(filename, string))
					tData[i][T_YSize] = dini_Float(filename, string);

		        format(string, sizeof(string), "%dT_Outline", i);
		    	if(dini_Isset(filename, string))
					tData[i][T_Outline] = dini_Int(filename, string);

		        format(string, sizeof(string), "%dT_Proportional", i);
		    	if(dini_Isset(filename, string))
					tData[i][T_Proportional] = dini_Int(filename, string);

		        format(string, sizeof(string), "%dT_Shadow", i);
		    	if(dini_Isset(filename, string))
					tData[i][T_Shadow] = dini_Int(filename, string);

		        format(string, sizeof(string), "%dT_Selectable", i);
		    	if(dini_Isset(filename, string))
					tData[i][T_Selectable] = dini_Int(filename, string);
					
		        format(string, sizeof(string), "%dT_Mode", i);
		    	if(dini_Isset(filename, string))
					tData[i][T_Mode] = dini_Int(filename, string);
					
				format(string, sizeof(string), "%dT_PreviewModel", i);
		    	if(dini_Isset(filename, string))
					tData[i][T_PreviewModel] = dini_Int(filename, string);

		        format(string, sizeof(string), "%dPMRotX", i);
		    	if(dini_Isset(filename, string))
					tData[i][PMRotX] = dini_Float(filename, string);

		        format(string, sizeof(string), "%dPMRotY", i);
		    	if(dini_Isset(filename, string))
					tData[i][PMRotY] = dini_Float(filename, string);

		        format(string, sizeof(string), "%dPMRotZ", i);
		    	if(dini_Isset(filename, string))
					tData[i][PMRotZ] = dini_Float(filename, string);

		        format(string, sizeof(string), "%dPMZoom", i);
		    	if(dini_Isset(filename, string))
					tData[i][PMZoom] = dini_Float(filename, string);

				// Normalize any legacy RRGGBBAA colors to AARRGGBB if file not marked ARGB
				if(!isARGB) NormalizeLoadedColors(i);
 				
 		        UpdateTextdraw(i);
 		    }
 		}
 		strmid(CurrentProject, filename, 0, strlen(filename) - 4, 128);
 		ShowTextDrawDialog(playerid, 4);
 	}
}

// Converts legacy packed color (RRGGBBAA) to ARGB if detected; no-op if already ARGB
stock NormalizeLoadedColors(tdid)
{
	// Heuristic: if alpha (low 8 bits) is neither 0x00 nor 0xFF while high 8 bits (assumed alpha in ARGB) is 0x00, likely legacy
	new c;
	// Text color
	c = tData[tdid][T_Color];
	if(((c >> 24) & 0xFF) == 0 && (c & 0xFF) != 0 && (c & 0xFF) != 0xFF)
	{
		new r = (c >> 24) & 0xFF; // 0 in legacy
		new g = (c >> 16) & 0xFF;
		new b = (c >> 8) & 0xFF;
		new a = c & 0xFF;
		tData[tdid][T_Color] = (a << 24) | (g << 16) | (b << 8) | 0; // We'll reconstruct properly below
		// Recompute with RGB for clarity
		tData[tdid][T_Color] = RGB((c >> 24) & 0xFF, (c >> 16) & 0xFF, (c >> 8) & 0xFF, a);
	}
	// Back color
	c = tData[tdid][T_BackColor];
	if(((c >> 24) & 0xFF) == 0 && (c & 0xFF) != 0 && (c & 0xFF) != 0xFF)
	{
		tData[tdid][T_BackColor] = RGB((c >> 24) & 0xFF, (c >> 16) & 0xFF, (c >> 8) & 0xFF, c & 0xFF);
	}
	// Box color
	c = tData[tdid][T_BoxColor];
	if(((c >> 24) & 0xFF) == 0 && (c & 0xFF) != 0 && (c & 0xFF) != 0xFF)
	{
		tData[tdid][T_BoxColor] = RGB((c >> 24) & 0xFF, (c >> 16) & 0xFF, (c >> 8) & 0xFF, c & 0xFF);
	}
}
stock ExportProject( playerid, type )
{
	/*  Exports a project.
	    @playerid:          ID of the player exporting the project.
	    @type:              Type of export requested:
	        - Type 0:       Classic export type
 	*/
 	SendClientMessage(playerid, MSG_COLOR, "O projeto está sendo exportado, por favor aguarde...");
 	
 	new filename[135], tmpstring[1152];
 	if(type == 0)	format(filename, sizeof(filename), "%s.txt", CurrentProject);
 	else if(type == 7)	format(filename, sizeof(filename), "%s.txt", CurrentProject);
 	else if(type == 8)	format(filename, sizeof(filename), "%s.txt", CurrentProject);
 	else		  	format(filename, sizeof(filename), "%s.pwn", CurrentProject);
 	new File:File = fopen(filename, io_write);
	switch(type)
	{
		case 0: // Classic export.
	    {
	        fwrite(File, "// TextDraw developed using Zamaroht's Textdraw Editor 1.0\r\n\r\n");
	        fwrite(File, "// On top of script:\r\n");
	        for(new i; i < MAX_TEXTDRAWS; i++)
	        {
	            if(tData[i][T_Created])
				{
					format(tmpstring, sizeof(tmpstring), "new Text:Textdraw%d;\r\n", i);
					fwrite(File, tmpstring);
				}
	        }
	        fwrite(File, "\r\n// In OnGameModeInit prefferably, we procced to create our textdraws:\r\n");
	        for(new i; i < MAX_TEXTDRAWS; i++)
	        {
	            if(tData[i][T_Created])
				{
					format(tmpstring, sizeof(tmpstring), "Textdraw%d = TextDrawCreate(%f, %f, \"%s\");\r\n", i, tData[i][T_X], tData[i][T_Y], tData[i][T_Text]);
					fwrite(File, tmpstring);
					if(tData[i][T_Alignment] != 0 && tData[i][T_Alignment] != 1)
					{
						format(tmpstring, sizeof(tmpstring), "TextDrawAlignment(Textdraw%d, %d);\r\n", i, tData[i][T_Alignment]);
						fwrite(File, tmpstring);
					}
					format(tmpstring, sizeof(tmpstring), "TextDrawBackgroundColor(Textdraw%d, %d);\r\n", i, tData[i][T_BackColor]);
					fwrite(File, tmpstring);
					format(tmpstring, sizeof(tmpstring), "TextDrawFont(Textdraw%d, %d);\r\n", i, tData[i][T_Font]);
					fwrite(File, tmpstring);
					format(tmpstring, sizeof(tmpstring), "TextDrawLetterSize(Textdraw%d, %f, %f);\r\n", i, tData[i][T_XSize], tData[i][T_YSize]);
					fwrite(File, tmpstring);
					format(tmpstring, sizeof(tmpstring), "TextDrawColor(Textdraw%d, %d);\r\n", i, tData[i][T_Color]);
					fwrite(File, tmpstring);
					format(tmpstring, sizeof(tmpstring), "TextDrawSetOutline(Textdraw%d, %d);\r\n", i, tData[i][T_Outline]);
					fwrite(File, tmpstring);
					format(tmpstring, sizeof(tmpstring), "TextDrawSetProportional(Textdraw%d, %d);\r\n", i, tData[i][T_Proportional]);
					fwrite(File, tmpstring);
					if(tData[i][T_Outline] == 0)
					{
					    format(tmpstring, sizeof(tmpstring), "TextDrawSetShadow(Textdraw%d, %d);\r\n", i, tData[i][T_Shadow]);
						fwrite(File, tmpstring);
					}
					if(tData[i][T_UseBox] == 1)
					{
					    format(tmpstring, sizeof(tmpstring), "TextDrawUseBox(Textdraw%d, %d);\r\n", i, tData[i][T_UseBox]);
						fwrite(File, tmpstring);
						format(tmpstring, sizeof(tmpstring), "TextDrawBoxColor(Textdraw%d, %d);\r\n", i, tData[i][T_BoxColor]);
						fwrite(File, tmpstring);
						format(tmpstring, sizeof(tmpstring), "TextDrawTextSize(Textdraw%d, %f, %f);\r\n", i, tData[i][T_TextSizeX], tData[i][T_TextSizeY]);
						fwrite(File, tmpstring);
					}
					if(tData[i][T_PreviewModel] > -1)
					{
					    format(tmpstring, sizeof(tmpstring), "TextDrawSetPreviewModel(Textdraw%d, %d);\r\n", i, tData[i][T_PreviewModel]);
					    fwrite(File, tmpstring);
					    format(tmpstring, sizeof(tmpstring), "TextDrawSetPreviewRot(Textdraw%d, %f, %f, %f, %f);\r\n", i, tData[i][PMRotX], tData[i][PMRotY], tData[i][PMRotZ], tData[i][PMZoom]);
					    fwrite(File, tmpstring);
					}
					format(tmpstring, sizeof(tmpstring), "TextDrawSetSelectable(Textdraw%d, %d);\r\n", i, tData[i][T_Selectable]);
					fwrite(File, tmpstring);
					fwrite(File, "\r\n");
				}
	        }
	        fwrite(File, "// You can now use TextDrawShowForPlayer(-ForAll), TextDrawHideForPlayer(-ForAll) and\r\n");
	        fwrite(File, "// TextDrawDestroy functions to show, hide, and destroy the textdraw.");

			format(tmpstring, sizeof(tmpstring), "Projeto exportado para %s.txt no diretório scriptfiles.", CurrentProject);
	        SendClientMessage(playerid, MSG_COLOR, tmpstring);
	    }
	    case 1: // Show all the time
	    {
	        fwrite(File, "/*\r\n");
	        fwrite(File, "Filterscript generated using Zamaroht's TextDraw Editor Version 1.0.\r\n");
	        fwrite(File, "Designed for SA-MP 0.3a.\r\n\r\n");
	        new ye,mo,da,ho,mi,se;
	        getdate(ye,mo,da);
	        gettime(ho,mi,se);
			format(tmpstring, sizeof(tmpstring), "Time and Date: %d-%d-%d @ %d:%d:%d\r\n\r\n", ye, mo, da, ho, mi, se);
			fwrite(File, tmpstring);
			fwrite(File, "Instructions:\r\n");
			fwrite(File, "1- Compile this file using the compiler provided with the sa-mp server package.\r\n");
			fwrite(File, "2- Copy the .amx file to the filterscripts directory.\r\n");
			fwrite(File, "3- Add the filterscripts in the server.cfg file (more info here:\r\n");
			fwrite(File, "http://wiki.sa-mp.com/wiki/Server.cfg)\r\n");
			fwrite(File, "4- Run the server!\r\n\r\n");
			fwrite(File, "Disclaimer:\r\n");
			fwrite(File, "You have full rights over this file. You can distribute it, modify it, and\r\n");
			fwrite(File, "change it as much as you want, without having to give any special credits.\r\n");
			fwrite(File, "*/\r\n\r\n");
			fwrite(File, "#include <a_samp>\r\n\r\n");
            for(new i; i < MAX_TEXTDRAWS; i++)
	        {
	            if(tData[i][T_Created])
				{
					format(tmpstring, sizeof(tmpstring), "new Text:Textdraw%d;\r\n", i);
					fwrite(File, tmpstring);
				}
	        }
			fwrite(File, "\r\npublic OnFilterScriptInit()\r\n");
			fwrite(File, "{\r\n");
			fwrite(File, "	print(\"Textdraw file generated by\");\r\n");
			fwrite(File, "	print(\"    Zamaroht's textdraw editor was loaded.\");\r\n\r\n");
			fwrite(File, "	// Create the textdraws:\r\n");
			for(new i; i < MAX_TEXTDRAWS; i++)
	        {
	            if(tData[i][T_Created])
				{
					format(tmpstring, sizeof(tmpstring), "	Textdraw%d = TextDrawCreate(%f, %f, \"%s\");\r\n", i, tData[i][T_X], tData[i][T_Y], tData[i][T_Text]);
					fwrite(File, tmpstring);
					if(tData[i][T_Alignment] != 0 && tData[i][T_Alignment] != 1)
					{
						format(tmpstring, sizeof(tmpstring), "	TextDrawAlignment(Textdraw%d, %d);\r\n", i, tData[i][T_Alignment]);
						fwrite(File, tmpstring);
					}
					format(tmpstring, sizeof(tmpstring), "	TextDrawBackgroundColor(Textdraw%d, %d);\r\n", i, tData[i][T_BackColor]);
					fwrite(File, tmpstring);
					format(tmpstring, sizeof(tmpstring), "	TextDrawFont(Textdraw%d, %d);\r\n", i, tData[i][T_Font]);
					fwrite(File, tmpstring);
					format(tmpstring, sizeof(tmpstring), "	TextDrawLetterSize(Textdraw%d, %f, %f);\r\n", i, tData[i][T_XSize], tData[i][T_YSize]);
					fwrite(File, tmpstring);
					format(tmpstring, sizeof(tmpstring), "	TextDrawColor(Textdraw%d, %d);\r\n", i, tData[i][T_Color]);
					fwrite(File, tmpstring);
					format(tmpstring, sizeof(tmpstring), "	TextDrawSetOutline(Textdraw%d, %d);\r\n", i, tData[i][T_Outline]);
					fwrite(File, tmpstring);
					format(tmpstring, sizeof(tmpstring), "	TextDrawSetProportional(Textdraw%d, %d);\r\n", i, tData[i][T_Proportional]);
					fwrite(File, tmpstring);
					if(tData[i][T_Outline] == 0)
					{
					    format(tmpstring, sizeof(tmpstring), "	TextDrawSetShadow(Textdraw%d, %d);\r\n", i, tData[i][T_Shadow]);
						fwrite(File, tmpstring);
					}
					if(tData[i][T_UseBox] == 1)
					{
					    format(tmpstring, sizeof(tmpstring), "	TextDrawUseBox(Textdraw%d, %d);\r\n", i, tData[i][T_UseBox]);
						fwrite(File, tmpstring);
						format(tmpstring, sizeof(tmpstring), "	TextDrawBoxColor(Textdraw%d, %d);\r\n", i, tData[i][T_BoxColor]);
						fwrite(File, tmpstring);
						format(tmpstring, sizeof(tmpstring), "	TextDrawTextSize(Textdraw%d, %f, %f);\r\n", i, tData[i][T_TextSizeX], tData[i][T_TextSizeY]);
						fwrite(File, tmpstring);
					}
					format(tmpstring, sizeof(tmpstring), "	TextDrawSetSelectable(Textdraw%d, %d);\r\n", i, tData[i][T_Selectable]);
					fwrite(File, tmpstring);
					fwrite(File, "\r\n");
				}
	        }
	        fwrite(File, "	for(new i; i < MAX_PLAYERS; i ++)\r\n");
	        fwrite(File, "	{\r\n");
	        fwrite(File, "		if(IsPlayerConnected(i))\r\n");
	        fwrite(File, "		{\r\n");
	        for(new i; i < MAX_TEXTDRAWS; i ++)
			{
			    if(tData[i][T_Created])
			    {
			        format(tmpstring, sizeof(tmpstring), "			TextDrawShowForPlayer(i, Textdraw%d);\r\n", i);
					fwrite(File, tmpstring);
			    }
			}
			fwrite(File, "		}\r\n");
			fwrite(File, "	}\r\n");
			fwrite(File, "	return 1;\r\n");
			fwrite(File, "}\r\n\r\n");
			fwrite(File, "public OnFilterScriptExit()\r\n");
			fwrite(File, "{\r\n");
            for(new i; i < MAX_TEXTDRAWS; i ++)
            {
                if(tData[i][T_Created])
                {
					format(tmpstring, sizeof(tmpstring), "	TextDrawHideForAll(Textdraw%d);\r\n", i);
					fwrite(File, tmpstring);
					format(tmpstring, sizeof(tmpstring), "	TextDrawDestroy(Textdraw%d);\r\n", i);
					fwrite(File, tmpstring);
                }
            }
			fwrite(File, "	return 1;\r\n");
			fwrite(File, "}\r\n\r\n");
			fwrite(File, "public OnPlayerConnect(playerid)\r\n");
			fwrite(File, "{\r\n");
			for(new i; i < MAX_TEXTDRAWS; i ++)
			{
			    if(tData[i][T_Created])
			    {
			        format(tmpstring, sizeof(tmpstring), "	TextDrawShowForPlayer(playerid, Textdraw%d);\r\n", i);
					fwrite(File, tmpstring);
			    }
			}
			fwrite(File, "	return 1;\r\n");
			fwrite(File, "}\r\n");
			
			format(tmpstring, sizeof(tmpstring), "Project exported to %s.pwn in scriptfiles directory as a filterscript.", CurrentProject);
	        SendClientMessage(playerid, MSG_COLOR, tmpstring);
	    }
	    
	    case 2: // Show on class selection
	    {
            fwrite(File, "/*\r\n");
	        fwrite(File, "Filterscript generated using Zamaroht's TextDraw Editor Version 1.0.\r\n");
	        fwrite(File, "Designed for SA-MP 0.3a.\r\n\r\n");
	        new ye,mo,da,ho,mi,se;
	        getdate(ye,mo,da);
	        gettime(ho,mi,se);
			format(tmpstring, sizeof(tmpstring), "Time and Date: %d-%d-%d @ %d:%d:%d\r\n\r\n", ye, mo, da, ho, mi, se);
			fwrite(File, tmpstring);
			fwrite(File, "Instructions:\r\n");
			fwrite(File, "1- Compile this file using the compiler provided with the sa-mp server package.\r\n");
			fwrite(File, "2- Copy the .amx file to the filterscripts directory.\r\n");
			fwrite(File, "3- Add the filterscripts in the server.cfg file (more info here:\r\n");
			fwrite(File, "http://wiki.sa-mp.com/wiki/Server.cfg)\r\n");
			fwrite(File, "4- Run the server!\r\n\r\n");
			fwrite(File, "Disclaimer:\r\n");
			fwrite(File, "You have full rights over this file. You can distribute it, modify it, and\r\n");
			fwrite(File, "change it as much as you want, without having to give any special credits.\r\n");
			fwrite(File, "*/\r\n\r\n");
			fwrite(File, "#include <a_samp>\r\n\r\n");
            for(new i; i < MAX_TEXTDRAWS; i++)
	        {
	            if(tData[i][T_Created])
				{
					format(tmpstring, sizeof(tmpstring), "new Text:Textdraw%d;\r\n", i);
					fwrite(File, tmpstring);
				}
	        }
			fwrite(File, "\r\npublic OnFilterScriptInit()\r\n");
			fwrite(File, "{\r\n");
			fwrite(File, "	print(\"Textdraw file generated by\");\r\n");
			fwrite(File, "	print(\"    Zamaroht's textdraw editor was loaded.\");\r\n\r\n");
			fwrite(File, "	// Create the textdraws:\r\n");
			for(new i; i < MAX_TEXTDRAWS; i++)
	        {
	            if(tData[i][T_Created])
				{
					format(tmpstring, sizeof(tmpstring), "	Textdraw%d = TextDrawCreate(%f, %f, \"%s\");\r\n", i, tData[i][T_X], tData[i][T_Y], tData[i][T_Text]);
					fwrite(File, tmpstring);
					if(tData[i][T_Alignment] != 0 && tData[i][T_Alignment] != 1)
					{
						format(tmpstring, sizeof(tmpstring), "	TextDrawAlignment(Textdraw%d, %d);\r\n", i, tData[i][T_Alignment]);
						fwrite(File, tmpstring);
					}
					format(tmpstring, sizeof(tmpstring), "	TextDrawBackgroundColor(Textdraw%d, %d);\r\n", i, tData[i][T_BackColor]);
					fwrite(File, tmpstring);
					format(tmpstring, sizeof(tmpstring), "	TextDrawFont(Textdraw%d, %d);\r\n", i, tData[i][T_Font]);
					fwrite(File, tmpstring);
					format(tmpstring, sizeof(tmpstring), "	TextDrawLetterSize(Textdraw%d, %f, %f);\r\n", i, tData[i][T_XSize], tData[i][T_YSize]);
					fwrite(File, tmpstring);
					format(tmpstring, sizeof(tmpstring), "	TextDrawColor(Textdraw%d, %d);\r\n", i, tData[i][T_Color]);
					fwrite(File, tmpstring);
					format(tmpstring, sizeof(tmpstring), "	TextDrawSetOutline(Textdraw%d, %d);\r\n", i, tData[i][T_Outline]);
					fwrite(File, tmpstring);
					format(tmpstring, sizeof(tmpstring), "	TextDrawSetProportional(Textdraw%d, %d);\r\n", i, tData[i][T_Proportional]);
					fwrite(File, tmpstring);
					if(tData[i][T_Outline] == 0)
					{
					    format(tmpstring, sizeof(tmpstring), "	TextDrawSetShadow(Textdraw%d, %d);\r\n", i, tData[i][T_Shadow]);
						fwrite(File, tmpstring);
					}
					if(tData[i][T_UseBox] == 1)
					{
					    format(tmpstring, sizeof(tmpstring), "	TextDrawUseBox(Textdraw%d, %d);\r\n", i, tData[i][T_UseBox]);
						fwrite(File, tmpstring);
						format(tmpstring, sizeof(tmpstring), "	TextDrawBoxColor(Textdraw%d, %d);\r\n", i, tData[i][T_BoxColor]);
						fwrite(File, tmpstring);
						format(tmpstring, sizeof(tmpstring), "	TextDrawTextSize(Textdraw%d, %f, %f);\r\n", i, tData[i][T_TextSizeX], tData[i][T_TextSizeY]);
						fwrite(File, tmpstring);
					}
					format(tmpstring, sizeof(tmpstring), "	TextDrawSetSelectable(Textdraw%d, %d);\r\n", i, tData[i][T_Selectable]);
					fwrite(File, tmpstring);
					fwrite(File, "\r\n");
				}
	        }
	        fwrite(File, "	return 1;\r\n");
	        fwrite(File, "}\r\n\r\n");
	        fwrite(File, "public OnFilterScriptExit()\r\n");
			fwrite(File, "{\r\n");
            for(new i; i < MAX_TEXTDRAWS; i ++)
            {
                if(tData[i][T_Created])
                {
					format(tmpstring, sizeof(tmpstring), "	TextDrawHideForAll(Textdraw%d);\r\n", i);
					fwrite(File, tmpstring);
					format(tmpstring, sizeof(tmpstring), "	TextDrawDestroy(Textdraw%d);\r\n", i);
					fwrite(File, tmpstring);
                }
            }
			fwrite(File, "	return 1;\r\n");
			fwrite(File, "}\r\n\r\n");
			fwrite(File, "public OnPlayerRequestClass(playerid, classid)\r\n");
			fwrite(File, "{\r\n");
			for(new i; i < MAX_TEXTDRAWS; i ++)
			{
			    if(tData[i][T_Created])
			    {
			        format(tmpstring, sizeof(tmpstring), "	TextDrawShowForPlayer(playerid, Textdraw%d);\r\n", i);
					fwrite(File, tmpstring);
			    }
			}
			fwrite(File, "	return 1;\r\n");
			fwrite(File, "}\r\n\r\n");
			fwrite(File, "public OnPlayerSpawn(playerid)\r\n");
			fwrite(File, "{\r\n");
			for(new i; i < MAX_TEXTDRAWS; i ++)
			{
			    if(tData[i][T_Created])
			    {
			        format(tmpstring, sizeof(tmpstring), "	TextDrawHideForPlayer(playerid, Textdraw%d);\r\n", i);
					fwrite(File, tmpstring);
			    }
			}
			fwrite(File, "	return 1;\r\n");
			fwrite(File, "}\r\n\r\n");
			
			format(tmpstring, sizeof(tmpstring), "Project exported to %s.pwn in scriptfiles directory as a filterscript.", CurrentProject);
	        SendClientMessage(playerid, MSG_COLOR, tmpstring);
	    }
	    
	    case 3: // Show while in vehicle
	    {
	        fwrite(File, "/*\r\n");
	        fwrite(File, "Filterscript generated using Zamaroht's TextDraw Editor Version 1.0.\r\n");
	        fwrite(File, "Designed for SA-MP 0.3a.\r\n\r\n");
	        new ye,mo,da,ho,mi,se;
	        getdate(ye,mo,da);
	        gettime(ho,mi,se);
			format(tmpstring, sizeof(tmpstring), "Time and Date: %d-%d-%d @ %d:%d:%d\r\n\r\n", ye, mo, da, ho, mi, se);
			fwrite(File, tmpstring);
			fwrite(File, "Instructions:\r\n");
			fwrite(File, "1- Compile this file using the compiler provided with the sa-mp server package.\r\n");
			fwrite(File, "2- Copy the .amx file to the filterscripts directory.\r\n");
			fwrite(File, "3- Add the filterscripts in the server.cfg file (more info here:\r\n");
			fwrite(File, "http://wiki.sa-mp.com/wiki/Server.cfg)\r\n");
			fwrite(File, "4- Run the server!\r\n\r\n");
			fwrite(File, "Disclaimer:\r\n");
			fwrite(File, "You have full rights over this file. You can distribute it, modify it, and\r\n");
			fwrite(File, "change it as much as you want, without having to give any special credits.\r\n");
			fwrite(File, "*/\r\n\r\n");
			fwrite(File, "#include <a_samp>\r\n\r\n");
            for(new i; i < MAX_TEXTDRAWS; i++)
	        {
	            if(tData[i][T_Created])
				{
					format(tmpstring, sizeof(tmpstring), "new Text:Textdraw%d;\r\n", i);
					fwrite(File, tmpstring);
				}
	        }
			fwrite(File, "\r\npublic OnFilterScriptInit()\r\n");
			fwrite(File, "{\r\n");
			fwrite(File, "	print(\"Textdraw file generated by\");\r\n");
			fwrite(File, "	print(\"    Zamaroht's textdraw editor was loaded.\");\r\n\r\n");
			fwrite(File, "	// Create the textdraws:\r\n");
			for(new i; i < MAX_TEXTDRAWS; i++)
	        {
	            if(tData[i][T_Created])
				{
					format(tmpstring, sizeof(tmpstring), "	Textdraw%d = TextDrawCreate(%f, %f, \"%s\");\r\n", i, tData[i][T_X], tData[i][T_Y], tData[i][T_Text]);
					fwrite(File, tmpstring);
					if(tData[i][T_Alignment] != 0 && tData[i][T_Alignment] != 1)
					{
						format(tmpstring, sizeof(tmpstring), "	TextDrawAlignment(Textdraw%d, %d);\r\n", i, tData[i][T_Alignment]);
						fwrite(File, tmpstring);
					}
					format(tmpstring, sizeof(tmpstring), "	TextDrawBackgroundColor(Textdraw%d, %d);\r\n", i, tData[i][T_BackColor]);
					fwrite(File, tmpstring);
					format(tmpstring, sizeof(tmpstring), "	TextDrawFont(Textdraw%d, %d);\r\n", i, tData[i][T_Font]);
					fwrite(File, tmpstring);
					format(tmpstring, sizeof(tmpstring), "	TextDrawLetterSize(Textdraw%d, %f, %f);\r\n", i, tData[i][T_XSize], tData[i][T_YSize]);
					fwrite(File, tmpstring);
					format(tmpstring, sizeof(tmpstring), "	TextDrawColor(Textdraw%d, %d);\r\n", i, tData[i][T_Color]);
					fwrite(File, tmpstring);
					format(tmpstring, sizeof(tmpstring), "	TextDrawSetOutline(Textdraw%d, %d);\r\n", i, tData[i][T_Outline]);
					fwrite(File, tmpstring);
					format(tmpstring, sizeof(tmpstring), "	TextDrawSetProportional(Textdraw%d, %d);\r\n", i, tData[i][T_Proportional]);
					fwrite(File, tmpstring);
					if(tData[i][T_Outline] == 0)
					{
					    format(tmpstring, sizeof(tmpstring), "	TextDrawSetShadow(Textdraw%d, %d);\r\n", i, tData[i][T_Shadow]);
						fwrite(File, tmpstring);
					}
					if(tData[i][T_UseBox] == 1)
					{
					    format(tmpstring, sizeof(tmpstring), "	TextDrawUseBox(Textdraw%d, %d);\r\n", i, tData[i][T_UseBox]);
						fwrite(File, tmpstring);
						format(tmpstring, sizeof(tmpstring), "	TextDrawBoxColor(Textdraw%d, %d);\r\n", i, tData[i][T_BoxColor]);
						fwrite(File, tmpstring);
						format(tmpstring, sizeof(tmpstring), "	TextDrawTextSize(Textdraw%d, %f, %f);\r\n", i, tData[i][T_TextSizeX], tData[i][T_TextSizeY]);
						fwrite(File, tmpstring);
					}
					format(tmpstring, sizeof(tmpstring), "	TextDrawSetSelectable(Textdraw%d, %d);\r\n", i, tData[i][T_Selectable]);
					fwrite(File, tmpstring);
					fwrite(File, "\r\n");
				}
	        }
	        fwrite(File, "	return 1;\r\n");
	        fwrite(File, "}\r\n\r\n");
	        fwrite(File, "public OnFilterScriptExit()\r\n");
			fwrite(File, "{\r\n");
            for(new i; i < MAX_TEXTDRAWS; i ++)
            {
                if(tData[i][T_Created])
                {
					format(tmpstring, sizeof(tmpstring), "	TextDrawHideForAll(Textdraw%d);\r\n", i);
					fwrite(File, tmpstring);
					format(tmpstring, sizeof(tmpstring), "	TextDrawDestroy(Textdraw%d);\r\n", i);
					fwrite(File, tmpstring);
                }
            }
			fwrite(File, "	return 1;\r\n");
			fwrite(File, "}\r\n\r\n");
			fwrite(File, "public OnPlayerStateChange(playerid, newstate, oldstate)\r\n");
			fwrite(File, "{\r\n");
			fwrite(File, "	if(newstate == PLAYER_STATE_DRIVER || newstate == PLAYER_STATE_PASSENGER)\r\n");
			fwrite(File, "	{\r\n");
			for(new i; i < MAX_TEXTDRAWS; i ++)
			{
			    if(tData[i][T_Created])
			    {
			        format(tmpstring, sizeof(tmpstring), "		TextDrawShowForPlayer(playerid, Textdraw%d);\r\n", i);
					fwrite(File, tmpstring);
			    }
			}
			fwrite(File, "	}\r\n");
			fwrite(File, "	else if(oldstate == PLAYER_STATE_DRIVER || oldstate == PLAYER_STATE_PASSENGER)\r\n");
			fwrite(File, "	{\r\n");
			for(new i; i < MAX_TEXTDRAWS; i ++)
			{
			    if(tData[i][T_Created])
			    {
			        format(tmpstring, sizeof(tmpstring), "		TextDrawHideForPlayer(playerid, Textdraw%d);\r\n", i);
					fwrite(File, tmpstring);
			    }
			}
			fwrite(File, "	}\r\n");
			fwrite(File, "	return 1;\r\n");
			fwrite(File, "}\r\n");
			
			format(tmpstring, sizeof(tmpstring), "Project exported to %s.pwn in scriptfiles directory as a filterscript.", CurrentProject);
	        SendClientMessage(playerid, MSG_COLOR, tmpstring);
	    }
	    
	    case 4: // Use command
	    {
	        fwrite(File, "/*\r\n");
	        fwrite(File, "Filterscript generated using Zamaroht's TextDraw Editor Version 1.0.\r\n");
	        fwrite(File, "Designed for SA-MP 0.3a.\r\n\r\n");
	        new ye,mo,da,ho,mi,se;
	        getdate(ye,mo,da);
	        gettime(ho,mi,se);
			format(tmpstring, sizeof(tmpstring), "Time and Date: %d-%d-%d @ %d:%d:%d\r\n\r\n", ye, mo, da, ho, mi, se);
			fwrite(File, tmpstring);
			fwrite(File, "Instructions:\r\n");
			fwrite(File, "1- Compile this file using the compiler provided with the sa-mp server package.\r\n");
			fwrite(File, "2- Copy the .amx file to the filterscripts directory.\r\n");
			fwrite(File, "3- Add the filterscripts in the server.cfg file (more info here:\r\n");
			fwrite(File, "http://wiki.sa-mp.com/wiki/Server.cfg)\r\n");
			fwrite(File, "4- Run the server!\r\n\r\n");
			fwrite(File, "Disclaimer:\r\n");
			fwrite(File, "You have full rights over this file. You can distribute it, modify it, and\r\n");
			fwrite(File, "change it as much as you want, without having to give any special credits.\r\n");
			fwrite(File, "*/\r\n\r\n");
			fwrite(File, "#include <a_samp>\r\n\r\n");
			fwrite(File, "new Showing[MAX_PLAYERS];\r\n\r\n");
            for(new i; i < MAX_TEXTDRAWS; i++)
	        {
	            if(tData[i][T_Created])
				{
					format(tmpstring, sizeof(tmpstring), "new Text:Textdraw%d;\r\n", i);
					fwrite(File, tmpstring);
				}
	        }
	        fwrite(File, "\r\npublic OnFilterScriptInit()\r\n");
			fwrite(File, "{\r\n");
			fwrite(File, "	print(\"Textdraw file generated by\");\r\n");
			fwrite(File, "	print(\"    Zamaroht's textdraw editor was loaded.\");\r\n\r\n");
			fwrite(File, "	// Create the textdraws:\r\n");
			for(new i; i < MAX_TEXTDRAWS; i++)
	        {
	            if(tData[i][T_Created])
				{
					format(tmpstring, sizeof(tmpstring), "	Textdraw%d = TextDrawCreate(%f, %f, \"%s\");\r\n", i, tData[i][T_X], tData[i][T_Y], tData[i][T_Text]);
					fwrite(File, tmpstring);
					if(tData[i][T_Alignment] != 0 && tData[i][T_Alignment] != 1)
					{
						format(tmpstring, sizeof(tmpstring), "	TextDrawAlignment(Textdraw%d, %d);\r\n", i, tData[i][T_Alignment]);
						fwrite(File, tmpstring);
					}
					format(tmpstring, sizeof(tmpstring), "	TextDrawBackgroundColor(Textdraw%d, %d);\r\n", i, tData[i][T_BackColor]);
					fwrite(File, tmpstring);
					format(tmpstring, sizeof(tmpstring), "	TextDrawFont(Textdraw%d, %d);\r\n", i, tData[i][T_Font]);
					fwrite(File, tmpstring);
					format(tmpstring, sizeof(tmpstring), "	TextDrawLetterSize(Textdraw%d, %f, %f);\r\n", i, tData[i][T_XSize], tData[i][T_YSize]);
					fwrite(File, tmpstring);
					format(tmpstring, sizeof(tmpstring), "	TextDrawColor(Textdraw%d, %d);\r\n", i, tData[i][T_Color]);
					fwrite(File, tmpstring);
					format(tmpstring, sizeof(tmpstring), "	TextDrawSetOutline(Textdraw%d, %d);\r\n", i, tData[i][T_Outline]);
					fwrite(File, tmpstring);
					format(tmpstring, sizeof(tmpstring), "	TextDrawSetProportional(Textdraw%d, %d);\r\n", i, tData[i][T_Proportional]);
					fwrite(File, tmpstring);
					if(tData[i][T_Outline] == 0)
					{
					    format(tmpstring, sizeof(tmpstring), "	TextDrawSetShadow(Textdraw%d, %d);\r\n", i, tData[i][T_Shadow]);
						fwrite(File, tmpstring);
					}
					if(tData[i][T_UseBox] == 1)
					{
					    format(tmpstring, sizeof(tmpstring), "	TextDrawUseBox(Textdraw%d, %d);\r\n", i, tData[i][T_UseBox]);
						fwrite(File, tmpstring);
						format(tmpstring, sizeof(tmpstring), "	TextDrawBoxColor(Textdraw%d, %d);\r\n", i, tData[i][T_BoxColor]);
						fwrite(File, tmpstring);
						format(tmpstring, sizeof(tmpstring), "	TextDrawTextSize(Textdraw%d, %f, %f);\r\n", i, tData[i][T_TextSizeX], tData[i][T_TextSizeY]);
						fwrite(File, tmpstring);
					}
					format(tmpstring, sizeof(tmpstring), "	TextDrawSetSelectable(Textdraw%d, %d);\r\n", i, tData[i][T_Selectable]);
					fwrite(File, tmpstring);
					fwrite(File, "\r\n");
				}
	        }
	        fwrite(File, "	return 1;\r\n");
	        fwrite(File, "}\r\n\r\n");
	        fwrite(File, "public OnFilterScriptExit()\r\n");
			fwrite(File, "{\r\n");
            for(new i; i < MAX_TEXTDRAWS; i ++)
            {
                if(tData[i][T_Created])
                {
					format(tmpstring, sizeof(tmpstring), "	TextDrawHideForAll(Textdraw%d);\r\n", i);
					fwrite(File, tmpstring);
					format(tmpstring, sizeof(tmpstring), "	TextDrawDestroy(Textdraw%d);\r\n", i);
					fwrite(File, tmpstring);
                }
            }
			fwrite(File, "	return 1;\r\n");
			fwrite(File, "}\r\n\r\n");
			fwrite(File, "public OnPlayerConnect(playerid)\r\n");
			fwrite(File, "{\r\n");
			fwrite(File, "	Showing[playerid] = 0;\r\n");
			fwrite(File, "}\r\n\r\n");
			fwrite(File, "public OnPlayerCommandText(playerid, cmdtext[])\r\n");
			fwrite(File, "{\r\n");
			if(pData[playerid][P_Aux] != 0)
			{
			    format(tmpstring, sizeof(tmpstring), "	if(!strcmp(cmdtext, \"%s\") && Showing[playerid] == 0)\r\n", pData[playerid][P_ExpCommand]);
			    fwrite(File, tmpstring);
			}
			else
			{
			    format(tmpstring, sizeof(tmpstring), "	if(!strcmp(cmdtext, \"%s\"))\r\n", pData[playerid][P_ExpCommand]);
			    fwrite(File, tmpstring);
			}
			fwrite(File, "	{\r\n");
			fwrite(File, "		if(Showing[playerid] == 1)\r\n");
			fwrite(File, "		{\r\n");
			fwrite(File, "			Showing[playerid] = 0;\r\n");
			for(new i; i < MAX_TEXTDRAWS; i ++)
			{
			    if(tData[i][T_Created])
			    {
			        format(tmpstring, sizeof(tmpstring), "			TextDrawHideForPlayer(playerid, Textdraw%d);\r\n", i);
					fwrite(File, tmpstring);
			    }
			}
			fwrite(File, "		}\r\n");
			fwrite(File, "		else\r\n");
			fwrite(File, "		{\r\n");
			fwrite(File, "			Showing[playerid] = 1;\r\n");
			for(new i; i < MAX_TEXTDRAWS; i ++)
			{
			    if(tData[i][T_Created])
			    {
			        format(tmpstring, sizeof(tmpstring), "			TextDrawShowForPlayer(playerid, Textdraw%d);\r\n", i);
					fwrite(File, tmpstring);
			    }
			}
			if(pData[playerid][P_Aux] != 0)
			{
			    format(tmpstring, sizeof(tmpstring), "			SetTimerEx(\"HideTextdraws\", %d, 0, \"i\", playerid);\r\n", pData[playerid][P_Aux]*1000);
				fwrite(File, tmpstring);
			}
			fwrite(File, "		}\r\n");
			fwrite(File, "	}\r\n");
			fwrite(File, "	return 1;\r\n");
			fwrite(File, "}\r\n");
            if(pData[playerid][P_Aux] != 0)
			{
			    fwrite(File, "\r\n");
			    fwrite(File, "forward HideTextdraws(playerid);\r\n");
			    fwrite(File, "public HideTextdraws(playerid)\r\n");
			    fwrite(File, "{\r\n");
			    fwrite(File, "	Showing[playerid] = 0;\r\n");
			    for(new i; i < MAX_TEXTDRAWS; i ++)
				{
				    if(tData[i][T_Created])
				    {
				        format(tmpstring, sizeof(tmpstring), "	TextDrawHideForPlayer(playerid, Textdraw%d);\r\n", i);
						fwrite(File, tmpstring);
				    }
				}
				fwrite(File, "}\r\n");
			}
			
			format(tmpstring, sizeof(tmpstring), "Project exported to %s.pwn in scriptfiles directory as a filterscript.", CurrentProject);
	        SendClientMessage(playerid, MSG_COLOR, tmpstring);
	    }
	    
	    case 5: // Every X time
	    {
	        fwrite(File, "/*\r\n");
	        fwrite(File, "Filterscript generated using Zamaroht's TextDraw Editor Version 1.0.\r\n");
	        fwrite(File, "Designed for SA-MP 0.3a.\r\n\r\n");
	        new ye,mo,da,ho,mi,se;
	        getdate(ye,mo,da);
	        gettime(ho,mi,se);
			format(tmpstring, sizeof(tmpstring), "Time and Date: %d-%d-%d @ %d:%d:%d\r\n\r\n", ye, mo, da, ho, mi, se);
			fwrite(File, tmpstring);
			fwrite(File, "Instructions:\r\n");
			fwrite(File, "1- Compile this file using the compiler provided with the sa-mp server package.\r\n");
			fwrite(File, "2- Copy the .amx file to the filterscripts directory.\r\n");
			fwrite(File, "3- Add the filterscripts in the server.cfg file (more info here:\r\n");
			fwrite(File, "http://wiki.sa-mp.com/wiki/Server.cfg)\r\n");
			fwrite(File, "4- Run the server!\r\n\r\n");
			fwrite(File, "Disclaimer:\r\n");
			fwrite(File, "You have full rights over this file. You can distribute it, modify it, and\r\n");
			fwrite(File, "change it as much as you want, without having to give any special credits.\r\n");
			fwrite(File, "*/\r\n\r\n");
			fwrite(File, "#include <a_samp>\r\n\r\n");
			fwrite(File, "new Timer;\r\n\r\n");
			for(new i; i < MAX_TEXTDRAWS; i++)
	        {
	            if(tData[i][T_Created])
				{
					format(tmpstring, sizeof(tmpstring), "new Text:Textdraw%d;\r\n", i);
					fwrite(File, tmpstring);
				}
	        }
	        fwrite(File, "\r\npublic OnFilterScriptInit()\r\n");
			fwrite(File, "{\r\n");
			fwrite(File, "	print(\"Textdraw file generated by\");\r\n");
			fwrite(File, "	print(\"    Zamaroht's textdraw editor was loaded.\");\r\n\r\n");
			fwrite(File, "	// Create the textdraws:\r\n");
			for(new i; i < MAX_TEXTDRAWS; i++)
	        {
	            if(tData[i][T_Created])
				{
					format(tmpstring, sizeof(tmpstring), "	Textdraw%d = TextDrawCreate(%f, %f, \"%s\");\r\n", i, tData[i][T_X], tData[i][T_Y], tData[i][T_Text]);
					fwrite(File, tmpstring);
					if(tData[i][T_Alignment] != 0 && tData[i][T_Alignment] != 1)
					{
						format(tmpstring, sizeof(tmpstring), "	TextDrawAlignment(Textdraw%d, %d);\r\n", i, tData[i][T_Alignment]);
						fwrite(File, tmpstring);
					}
					format(tmpstring, sizeof(tmpstring), "	TextDrawBackgroundColor(Textdraw%d, %d);\r\n", i, tData[i][T_BackColor]);
					fwrite(File, tmpstring);
					format(tmpstring, sizeof(tmpstring), "	TextDrawFont(Textdraw%d, %d);\r\n", i, tData[i][T_Font]);
					fwrite(File, tmpstring);
					format(tmpstring, sizeof(tmpstring), "	TextDrawLetterSize(Textdraw%d, %f, %f);\r\n", i, tData[i][T_XSize], tData[i][T_YSize]);
					fwrite(File, tmpstring);
					format(tmpstring, sizeof(tmpstring), "	TextDrawColor(Textdraw%d, %d);\r\n", i, tData[i][T_Color]);
					fwrite(File, tmpstring);
					format(tmpstring, sizeof(tmpstring), "	TextDrawSetOutline(Textdraw%d, %d);\r\n", i, tData[i][T_Outline]);
					fwrite(File, tmpstring);
					format(tmpstring, sizeof(tmpstring), "	TextDrawSetProportional(Textdraw%d, %d);\r\n", i, tData[i][T_Proportional]);
					fwrite(File, tmpstring);
					if(tData[i][T_Outline] == 0)
					{
					    format(tmpstring, sizeof(tmpstring), "	TextDrawSetShadow(Textdraw%d, %d);\r\n", i, tData[i][T_Shadow]);
						fwrite(File, tmpstring);
					}
					if(tData[i][T_UseBox] == 1)
					{
					    format(tmpstring, sizeof(tmpstring), "	TextDrawUseBox(Textdraw%d, %d);\r\n", i, tData[i][T_UseBox]);
						fwrite(File, tmpstring);
						format(tmpstring, sizeof(tmpstring), "	TextDrawBoxColor(Textdraw%d, %d);\r\n", i, tData[i][T_BoxColor]);
						fwrite(File, tmpstring);
						format(tmpstring, sizeof(tmpstring), "	TextDrawTextSize(Textdraw%d, %f, %f);\r\n", i, tData[i][T_TextSizeX], tData[i][T_TextSizeY]);
						fwrite(File, tmpstring);
					}
					format(tmpstring, sizeof(tmpstring), "	TextDrawSetSelectable(Textdraw%d, %d);\r\n", i, tData[i][T_Selectable]);
					fwrite(File, tmpstring);
					fwrite(File, "\r\n");
				}
	        }
	        format(tmpstring, sizeof(tmpstring), "	Timer = SetTimer(\"ShowMessage\", %d, 1);\r\n", pData[playerid][P_Aux]*1000);
	        fwrite(File, tmpstring);
	        fwrite(File, "	return 1;\r\n");
	        fwrite(File, "}\r\n\r\n");
	        fwrite(File, "public OnFilterScriptExit()\r\n");
			fwrite(File, "{\r\n");
            for(new i; i < MAX_TEXTDRAWS; i ++)
            {
                if(tData[i][T_Created])
                {
					format(tmpstring, sizeof(tmpstring), "	TextDrawHideForAll(Textdraw%d);\r\n", i);
					fwrite(File, tmpstring);
					format(tmpstring, sizeof(tmpstring), "	TextDrawDestroy(Textdraw%d);\r\n", i);
					fwrite(File, tmpstring);
                }
            }
            fwrite(File, "	KillTimer(Timer);\r\n");
			fwrite(File, "	return 1;\r\n");
			fwrite(File, "}\r\n\r\n");
	        fwrite(File, "forward ShowMessage( );\r\n");
	        fwrite(File, "public ShowMessage( )\r\n");
	        fwrite(File, "{\r\n");
	        for(new i; i < MAX_TEXTDRAWS; i ++)
			{
			    if(tData[i][T_Created])
			    {
			        format(tmpstring, sizeof(tmpstring), "	TextDrawShowForAll(Textdraw%d);\r\n", i);
					fwrite(File, tmpstring);
			    }
			}
			format(tmpstring, sizeof(tmpstring), "	SetTimer(\"HideMessage\", %d, 1);\r\n", pData[playerid][P_Aux2]*1000);
			fwrite(File, tmpstring);
			fwrite(File, "}\r\n\r\n");
			fwrite(File, "forward HideMessage( );\r\n");
	        fwrite(File, "public HideMessage( )\r\n");
	        fwrite(File, "{\r\n");
	        for(new i; i < MAX_TEXTDRAWS; i ++)
			{
			    if(tData[i][T_Created])
			    {
			        format(tmpstring, sizeof(tmpstring), "	TextDrawHideForAll(Textdraw%d);\r\n", i);
					fwrite(File, tmpstring);
			    }
			}
	        fwrite(File, "}");
	        
	        format(tmpstring, sizeof(tmpstring), "Project exported to %s.pwn in scriptfiles directory as a filterscript.", CurrentProject);
	        SendClientMessage(playerid, MSG_COLOR, tmpstring);
	    }
	    
	    case 6: // After kill
	    {
	        fwrite(File, "/*\r\n");
	        fwrite(File, "Filterscript generated using Zamaroht's TextDraw Editor Version 1.0.\r\n");
	        fwrite(File, "Designed for SA-MP 0.3a.\r\n\r\n");
	        new ye,mo,da,ho,mi,se;
	        getdate(ye,mo,da);
	        gettime(ho,mi,se);
			format(tmpstring, sizeof(tmpstring), "Time and Date: %d-%d-%d @ %d:%d:%d\r\n\r\n", ye, mo, da, ho, mi, se);
			fwrite(File, tmpstring);
			fwrite(File, "Instructions:\r\n");
			fwrite(File, "1- Compile this file using the compiler provided with the sa-mp server package.\r\n");
			fwrite(File, "2- Copy the .amx file to the filterscripts directory.\r\n");
			fwrite(File, "3- Add the filterscripts in the server.cfg file (more info here:\r\n");
			fwrite(File, "http://wiki.sa-mp.com/wiki/Server.cfg)\r\n");
			fwrite(File, "4- Run the server!\r\n\r\n");
			fwrite(File, "Disclaimer:\r\n");
			fwrite(File, "You have full rights over this file. You can distribute it, modify it, and\r\n");
			fwrite(File, "change it as much as you want, without having to give any special credits.\r\n");
			fwrite(File, "*/\r\n\r\n");
			fwrite(File, "#include <a_samp>\r\n\r\n");
            for(new i; i < MAX_TEXTDRAWS; i++)
	        {
	            if(tData[i][T_Created])
				{
					format(tmpstring, sizeof(tmpstring), "new Text:Textdraw%d;\r\n", i);
					fwrite(File, tmpstring);
				}
	        }
			fwrite(File, "\r\npublic OnFilterScriptInit()\r\n");
			fwrite(File, "{\r\n");
			fwrite(File, "	print(\"Textdraw file generated by\");\r\n");
			fwrite(File, "	print(\"    Zamaroht's textdraw editor was loaded.\");\r\n\r\n");
			fwrite(File, "	// Create the textdraws:\r\n");
			for(new i; i < MAX_TEXTDRAWS; i++)
	        {
	            if(tData[i][T_Created])
				{
					format(tmpstring, sizeof(tmpstring), "	Textdraw%d = TextDrawCreate(%f, %f, \"%s\");\r\n", i, tData[i][T_X], tData[i][T_Y], tData[i][T_Text]);
					fwrite(File, tmpstring);
					if(tData[i][T_Alignment] != 0 && tData[i][T_Alignment] != 1)
					{
						format(tmpstring, sizeof(tmpstring), "	TextDrawAlignment(Textdraw%d, %d);\r\n", i, tData[i][T_Alignment]);
						fwrite(File, tmpstring);
					}
					format(tmpstring, sizeof(tmpstring), "	TextDrawBackgroundColor(Textdraw%d, %d);\r\n", i, tData[i][T_BackColor]);
					fwrite(File, tmpstring);
					format(tmpstring, sizeof(tmpstring), "	TextDrawFont(Textdraw%d, %d);\r\n", i, tData[i][T_Font]);
					fwrite(File, tmpstring);
					format(tmpstring, sizeof(tmpstring), "	TextDrawLetterSize(Textdraw%d, %f, %f);\r\n", i, tData[i][T_XSize], tData[i][T_YSize]);
					fwrite(File, tmpstring);
					format(tmpstring, sizeof(tmpstring), "	TextDrawColor(Textdraw%d, %d);\r\n", i, tData[i][T_Color]);
					fwrite(File, tmpstring);
					format(tmpstring, sizeof(tmpstring), "	TextDrawSetOutline(Textdraw%d, %d);\r\n", i, tData[i][T_Outline]);
					fwrite(File, tmpstring);
					format(tmpstring, sizeof(tmpstring), "	TextDrawSetProportional(Textdraw%d, %d);\r\n", i, tData[i][T_Proportional]);
					fwrite(File, tmpstring);
					if(tData[i][T_Outline] == 0)
					{
					    format(tmpstring, sizeof(tmpstring), "	TextDrawSetShadow(Textdraw%d, %d);\r\n", i, tData[i][T_Shadow]);
						fwrite(File, tmpstring);
					}
					if(tData[i][T_UseBox] == 1)
					{
					    format(tmpstring, sizeof(tmpstring), "	TextDrawUseBox(Textdraw%d, %d);\r\n", i, tData[i][T_UseBox]);
						fwrite(File, tmpstring);
						format(tmpstring, sizeof(tmpstring), "	TextDrawBoxColor(Textdraw%d, %d);\r\n", i, tData[i][T_BoxColor]);
						fwrite(File, tmpstring);
						format(tmpstring, sizeof(tmpstring), "	TextDrawTextSize(Textdraw%d, %f, %f);\r\n", i, tData[i][T_TextSizeX], tData[i][T_TextSizeY]);
						fwrite(File, tmpstring);
					}
					format(tmpstring, sizeof(tmpstring), "	TextDrawSetSelectable(Textdraw%d, %d);\r\n", i, tData[i][T_Selectable]);
					fwrite(File, tmpstring);
					fwrite(File, "\r\n");
				}
	        }
	        fwrite(File, "	return 1;\r\n");
	        fwrite(File, "}\r\n\r\n");
	        fwrite(File, "public OnFilterScriptExit()\r\n");
			fwrite(File, "{\r\n");
            for(new i; i < MAX_TEXTDRAWS; i ++)
            {
                if(tData[i][T_Created])
                {
					format(tmpstring, sizeof(tmpstring), "	TextDrawHideForAll(Textdraw%d);\r\n", i);
					fwrite(File, tmpstring);
					format(tmpstring, sizeof(tmpstring), "	TextDrawDestroy(Textdraw%d);\r\n", i);
					fwrite(File, tmpstring);
                }
            }
			fwrite(File, "	return 1;\r\n");
			fwrite(File, "}\r\n\r\n");
			fwrite(File, "public OnPlayerDeath(playerid, killerid, reason)\r\n");
			fwrite(File, "{\r\n");
			for(new i; i < MAX_TEXTDRAWS; i ++)
			{
			    if(tData[i][T_Created])
			    {
			        format(tmpstring, sizeof(tmpstring), "	TextDrawShowForPlayer(killerid, Textdraw%d);\r\n", i);
					fwrite(File, tmpstring);
			    }
			}
			format(tmpstring, sizeof(tmpstring), "	SetTimerEx(\"HideMessage\", %d, 0, \"i\", killerid);\r\n", pData[playerid][P_Aux]*1000);
			fwrite(File, tmpstring);
			fwrite(File, "}\r\n\r\n");
			fwrite(File, "forward HideMessage(playerid);\r\n");
			fwrite(File, "public HideMessage(playerid)\r\n");
			fwrite(File, "{\r\n");
			for(new i; i < MAX_TEXTDRAWS; i ++)
			{
			    if(tData[i][T_Created])
			    {
			        format(tmpstring, sizeof(tmpstring), "	TextDrawHideForPlayer(playerid, Textdraw%d);\r\n", i);
					fwrite(File, tmpstring);
			    }
			}
			fwrite(File, "}");
			
		    format(tmpstring, sizeof(tmpstring), "Project exported to %s.pwn in scriptfiles directory as a filterscript.", CurrentProject);
	        SendClientMessage(playerid, MSG_COLOR, tmpstring);
	    }
	    case 7: // PlayerTextDraw by adri1.
	    {
	        fwrite(File, "// TextDraw developed using Zamaroht's Textdraw Editor 1.0\r\n\r\n");
	        fwrite(File, "// The fuction `PlayerTextDraw´ add by adri1\r\n");
	        fwrite(File, "// On top of script:\r\n");
	        new p_count_7 = 0;
	        for(new i; i < MAX_TEXTDRAWS; i++)
	        {
	            if(tData[i][T_Created])
	                ++p_count_7;
	        }
	        format(tmpstring, sizeof(tmpstring), "new PlayerText:TextDrawsDoJogador[MAX_PLAYERS][%d];\r\n", p_count_7);
	        fwrite(File, tmpstring);
	        fwrite(File, "\r\n// In OnPlayerConnect prefferably, we procced to create our textdraws:\r\n");
	        for(new i, count_textdraws; i < MAX_TEXTDRAWS; i++)
	        {
	            if(tData[i][T_Created])
				{
					format(tmpstring, sizeof(tmpstring), "TextDrawsDoJogador[playerid][%d] = CreatePlayerTextDraw(playerid,%f, %f, \"%s\");\r\n", count_textdraws, tData[i][T_X], tData[i][T_Y], tData[i][T_Text]);
					fwrite(File, tmpstring);
					if(tData[i][T_Alignment] != 0 && tData[i][T_Alignment] != 1)
					{
						format(tmpstring, sizeof(tmpstring), "PlayerTextDrawAlignment(playerid,TextDrawsDoJogador[playerid][%d], %d);\r\n", count_textdraws, tData[i][T_Alignment]);
						fwrite(File, tmpstring);
					}
					format(tmpstring, sizeof(tmpstring), "PlayerTextDrawBackgroundColor(playerid,TextDrawsDoJogador[playerid][%d], %d);\r\n", count_textdraws, tData[i][T_BackColor]);
					fwrite(File, tmpstring);
					format(tmpstring, sizeof(tmpstring), "PlayerTextDrawFont(playerid,TextDrawsDoJogador[playerid][%d], %d);\r\n", count_textdraws, tData[i][T_Font]);
					fwrite(File, tmpstring);
					format(tmpstring, sizeof(tmpstring), "PlayerTextDrawLetterSize(playerid,TextDrawsDoJogador[playerid][%d], %f, %f);\r\n", count_textdraws, tData[i][T_XSize], tData[i][T_YSize]);
					fwrite(File, tmpstring);
					format(tmpstring, sizeof(tmpstring), "PlayerTextDrawColor(playerid,TextDrawsDoJogador[playerid][%d], %d);\r\n", count_textdraws, tData[i][T_Color]);
					fwrite(File, tmpstring);
					format(tmpstring, sizeof(tmpstring), "PlayerTextDrawSetOutline(playerid,TextDrawsDoJogador[playerid][%d], %d);\r\n", count_textdraws, tData[i][T_Outline]);
					fwrite(File, tmpstring);
					format(tmpstring, sizeof(tmpstring), "PlayerTextDrawSetProportional(playerid,TextDrawsDoJogador[playerid][%d], %d);\r\n", count_textdraws, tData[i][T_Proportional]);
					fwrite(File, tmpstring);
					if(tData[i][T_Outline] == 0)
					{
					    format(tmpstring, sizeof(tmpstring), "PlayerTextDrawSetShadow(playerid,TextDrawsDoJogador[playerid][%d], %d);\r\n", count_textdraws, tData[i][T_Shadow]);
						fwrite(File, tmpstring);
					}
					if(tData[i][T_UseBox] == 1)
					{
					    format(tmpstring, sizeof(tmpstring), "PlayerTextDrawUseBox(playerid,TextDrawsDoJogador[playerid][%d], %d);\r\n", count_textdraws, tData[i][T_UseBox]);
						fwrite(File, tmpstring);
						format(tmpstring, sizeof(tmpstring), "PlayerTextDrawBoxColor(playerid,TextDrawsDoJogador[playerid][%d], %d);\r\n", count_textdraws, tData[i][T_BoxColor]);
						fwrite(File, tmpstring);
					}
					format(tmpstring, sizeof(tmpstring), "PlayerTextDrawTextSize(playerid,TextDrawsDoJogador[playerid][%d], %f, %f);\r\n", count_textdraws, tData[i][T_TextSizeX], tData[i][T_TextSizeY]);
					fwrite(File, tmpstring);
					if(tData[i][T_PreviewModel] > -1)
					{
					    format(tmpstring, sizeof(tmpstring), "PlayerTextDrawSetPreviewModel(playerid, TextDrawsDoJogador[playerid][%d], %d);\r\n", count_textdraws, tData[i][T_PreviewModel]);
					    fwrite(File, tmpstring);
					    format(tmpstring, sizeof(tmpstring), "PlayerTextDrawSetPreviewRot(playerid, TextDrawsDoJogador[playerid][%d], %f, %f, %f, %f);\r\n", count_textdraws, tData[i][PMRotX], tData[i][PMRotY], tData[i][PMRotZ], tData[i][PMZoom]);
					    fwrite(File, tmpstring);
					}
					format(tmpstring, sizeof(tmpstring), "PlayerTextDrawSetSelectable(playerid,TextDrawsDoJogador[playerid][%d], %d);\r\n", count_textdraws, tData[i][T_Selectable]);
					fwrite(File, tmpstring);
					fwrite(File, "\r\n");

					++count_textdraws;
				}
	        }
	        fwrite(File, "// You can now use PlayerTextDrawShow, PlayerTextDrawHide and\r\n");
	        fwrite(File, "// PlayerTextDrawDestroy functions to show, hide, and destroy the textdraw.");

			format(tmpstring, sizeof(tmpstring), "Project exported to %s.txt in scriptfiles directory.", CurrentProject);
	        SendClientMessage(playerid, MSG_COLOR, tmpstring);
	        SendClientMessage(playerid, MSG_COLOR, "Fuction `PlayerTextDraw´ add by adri1");
	    }
		case 8: // Mixed export mode
	    {
	        fwrite(File, "// TextDraw developed using Zamaroht's Textdraw Editor 1.0\r\n\r\n");
	        fwrite(File, "// On top of script:\r\n");

			new g_count = 0;
			new p_count = 0;

			for(new i; i < MAX_TEXTDRAWS; i++)
	        {
	            if(tData[i][T_Created])
				{
					if (tData[i][T_Mode])
						++p_count;
					else
					    ++g_count;
				}
	        }
	        if (g_count)
	        {
				format(tmpstring, sizeof(tmpstring), "new Text:Textdraw[%d];\r\n", g_count);
				fwrite(File, tmpstring);
	        }
	        if (p_count)
	        {
				format(tmpstring, sizeof(tmpstring), "new PlayerText:TextDrawsDoJogador[MAX_PLAYERS][%d];\r\n", p_count);
				fwrite(File, tmpstring);
	        }

	        if (g_count)
	        {
	            fwrite(File, "\r\n// -----------------------------------------------------------------------------");
	            fwrite(File, "\r\n//                            GLOBAL TEXTDRAW'S");
	            fwrite(File, "\r\n// -----------------------------------------------------------------------------");
	            fwrite(File, "\r\n\n// In OnGameModeInit prefferably, we procced to create our textdraws:\r\n");
		        for(new i, count_textdraws; i < MAX_TEXTDRAWS; i++)
		        {
              		if(!tData[i][T_Created] || tData[i][T_Mode] != 0) continue;

					format(tmpstring, sizeof(tmpstring), "Textdraw[%d] = TextDrawCreate(%f, %f, \"%s\");\r\n", count_textdraws, tData[i][T_X], tData[i][T_Y], tData[i][T_Text]);
					fwrite(File, tmpstring);
					if(tData[i][T_Alignment] != 0 && tData[i][T_Alignment] != 1)
					{
						format(tmpstring, sizeof(tmpstring), "TextDrawAlignment(Textdraw[%d], %d);\r\n", count_textdraws, tData[i][T_Alignment]);
						fwrite(File, tmpstring);
					}
					format(tmpstring, sizeof(tmpstring), "TextDrawBackgroundColor(Textdraw[%d], %d);\r\n", count_textdraws, tData[i][T_BackColor]);
					fwrite(File, tmpstring);
					format(tmpstring, sizeof(tmpstring), "TextDrawFont(Textdraw[%d], %d);\r\n", count_textdraws, tData[i][T_Font]);
					fwrite(File, tmpstring);
					format(tmpstring, sizeof(tmpstring), "TextDrawLetterSize(Textdraw[%d], %f, %f);\r\n", count_textdraws, tData[i][T_XSize], tData[i][T_YSize]);
					fwrite(File, tmpstring);
					format(tmpstring, sizeof(tmpstring), "TextDrawColor(Textdraw[%d], %d);\r\n", count_textdraws, tData[i][T_Color]);
					fwrite(File, tmpstring);
					format(tmpstring, sizeof(tmpstring), "TextDrawSetOutline(Textdraw[%d], %d);\r\n", count_textdraws, tData[i][T_Outline]);
					fwrite(File, tmpstring);
					format(tmpstring, sizeof(tmpstring), "TextDrawSetProportional(Textdraw[%d], %d);\r\n", count_textdraws, tData[i][T_Proportional]);
					fwrite(File, tmpstring);
					if(tData[i][T_Outline] == 0)
					{
					    format(tmpstring, sizeof(tmpstring), "TextDrawSetShadow(Textdraw[%d], %d);\r\n", count_textdraws, tData[i][T_Shadow]);
						fwrite(File, tmpstring);
					}
					if(tData[i][T_UseBox] == 1)
					{
					    format(tmpstring, sizeof(tmpstring), "TextDrawUseBox(Textdraw[%d], %d);\r\n", count_textdraws, tData[i][T_UseBox]);
						fwrite(File, tmpstring);
						format(tmpstring, sizeof(tmpstring), "TextDrawBoxColor(Textdraw[%d], %d);\r\n", count_textdraws, tData[i][T_BoxColor]);
						fwrite(File, tmpstring);
						format(tmpstring, sizeof(tmpstring), "TextDrawTextSize(Textdraw[%d], %f, %f);\r\n", count_textdraws, tData[i][T_TextSizeX], tData[i][T_TextSizeY]);
						fwrite(File, tmpstring);
					}
					if(tData[i][T_PreviewModel] > -1)
					{
					    format(tmpstring, sizeof(tmpstring), "TextDrawSetPreviewModel(Textdraw[%d], %d);\r\n", count_textdraws, tData[i][T_PreviewModel]);
					    fwrite(File, tmpstring);
					    format(tmpstring, sizeof(tmpstring), "TextDrawSetPreviewRot(Textdraw[%d], %f, %f, %f, %f);\r\n", count_textdraws, tData[i][PMRotX], tData[i][PMRotY], tData[i][PMRotZ], tData[i][PMZoom]);
					    fwrite(File, tmpstring);
					}
					format(tmpstring, sizeof(tmpstring), "TextDrawSetSelectable(Textdraw[%d], %d);\r\n", count_textdraws, tData[i][T_Selectable]);
					fwrite(File, tmpstring);
					fwrite(File, "\r\n");

					++count_textdraws;
				}
	        	fwrite(File, "// You can now use TextDrawShowForPlayer(-ForAll), TextDrawHideForPlayer(-ForAll) and\r\n");
	        	fwrite(File, "// TextDrawDestroy functions to show, hide, and destroy the textdraw.\r\n");
	        }

	        if (p_count)
	        {
	            fwrite(File, "\r\n// -----------------------------------------------------------------------------");
	            fwrite(File, "\r\n//                            PER PLAYER TEXTDRAW'S");
	            fwrite(File, "\r\n// -----------------------------------------------------------------------------");
		        fwrite(File, "\r\n// In OnPlayerConnect prefferably, we procced to create our textdraws:\r\n");
		        for(new i, count_textdraws; i < MAX_TEXTDRAWS; i++)
		        {
		            if(!tData[i][T_Created] || tData[i][T_Mode] != 1) continue;

					format(tmpstring, sizeof(tmpstring), "TextDrawsDoJogador[playerid][%d] = CreatePlayerTextDraw(playerid, %f, %f, \"%s\");\r\n", count_textdraws, tData[i][T_X], tData[i][T_Y], tData[i][T_Text]);
					fwrite(File, tmpstring);
					if(tData[i][T_Alignment] != 0 && tData[i][T_Alignment] != 1)
					{
						format(tmpstring, sizeof(tmpstring), "PlayerTextDrawAlignment(playerid, TextDrawsDoJogador[playerid][%d], %d);\r\n", count_textdraws, tData[i][T_Alignment]);
						fwrite(File, tmpstring);
					}
					format(tmpstring, sizeof(tmpstring), "PlayerTextDrawBackgroundColor(playerid, TextDrawsDoJogador[playerid][%d], %d);\r\n", count_textdraws, tData[i][T_BackColor]);
					fwrite(File, tmpstring);
					format(tmpstring, sizeof(tmpstring), "PlayerTextDrawFont(playerid, TextDrawsDoJogador[playerid][%d], %d);\r\n", count_textdraws, tData[i][T_Font]);
					fwrite(File, tmpstring);
					format(tmpstring, sizeof(tmpstring), "PlayerTextDrawLetterSize(playerid, TextDrawsDoJogador[playerid][%d], %f, %f);\r\n", count_textdraws, tData[i][T_XSize], tData[i][T_YSize]);
					fwrite(File, tmpstring);
					format(tmpstring, sizeof(tmpstring), "PlayerTextDrawColor(playerid, TextDrawsDoJogador[playerid][%d], %d);\r\n", count_textdraws, tData[i][T_Color]);
					fwrite(File, tmpstring);
					format(tmpstring, sizeof(tmpstring), "PlayerTextDrawSetOutline(playerid, TextDrawsDoJogador[playerid][%d], %d);\r\n", count_textdraws, tData[i][T_Outline]);
					fwrite(File, tmpstring);
					format(tmpstring, sizeof(tmpstring), "PlayerTextDrawSetProportional(playerid, TextDrawsDoJogador[playerid][%d], %d);\r\n", count_textdraws, tData[i][T_Proportional]);
					fwrite(File, tmpstring);
					if(tData[i][T_Outline] == 0)
					{
					    format(tmpstring, sizeof(tmpstring), "PlayerTextDrawSetShadow(playerid, TextDrawsDoJogador[playerid][%d], %d);\r\n", count_textdraws, tData[i][T_Shadow]);
						fwrite(File, tmpstring);
					}
					if(tData[i][T_UseBox] == 1)
					{
					    format(tmpstring, sizeof(tmpstring), "PlayerTextDrawUseBox(playerid, TextDrawsDoJogador[playerid][%d], %d);\r\n", count_textdraws, tData[i][T_UseBox]);
						fwrite(File, tmpstring);
						format(tmpstring, sizeof(tmpstring), "PlayerTextDrawBoxColor(playerid, TextDrawsDoJogador[playerid][%d], %d);\r\n", count_textdraws, tData[i][T_BoxColor]);
						fwrite(File, tmpstring);
					}
					format(tmpstring, sizeof(tmpstring), "PlayerTextDrawTextSize(playerid, TextDrawsDoJogador[playerid][%d], %f, %f);\r\n", count_textdraws, tData[i][T_TextSizeX], tData[i][T_TextSizeY]);
					fwrite(File, tmpstring);
					if(tData[i][T_PreviewModel] > -1)
					{
					    format(tmpstring, sizeof(tmpstring), "PlayerTextDrawSetPreviewModel(playerid, TextDrawsDoJogador[playerid][%d], %d);\r\n", count_textdraws, tData[i][T_PreviewModel]);
					    fwrite(File, tmpstring);
					    format(tmpstring, sizeof(tmpstring), "PlayerTextDrawSetPreviewRot(playerid, TextDrawsDoJogador[playerid][%d], %f, %f, %f, %f);\r\n", count_textdraws, tData[i][PMRotX], tData[i][PMRotY], tData[i][PMRotZ], tData[i][PMZoom]);
					    fwrite(File, tmpstring);
					}
					format(tmpstring, sizeof(tmpstring), "PlayerTextDrawSetSelectable(playerid, TextDrawsDoJogador[playerid][%d], %d);\r\n", count_textdraws, tData[i][T_Selectable]);
					fwrite(File, tmpstring);
					fwrite(File, "\r\n");

					++count_textdraws;
				}
	        	fwrite(File, "// You can now use PlayerTextDrawShow, PlayerTextDrawHide and\r\n");
	        	fwrite(File, "// PlayerTextDrawDestroy functions to show, hide, and destroy the textdraw.");
	        }

			format(tmpstring, sizeof(tmpstring), "Projeto exportado para %s.txt no diretório scriptfiles.", CurrentProject);
	        SendClientMessage(playerid, MSG_COLOR, tmpstring);
	    }
	}
	fclose(File);
	
	ShowTextDrawDialog(playerid, 4);
}

// ================================================================================================================================
// -------------------------------------------------------- AUXILIAR FUNCTIONS ----------------------------------------------------
// ================================================================================================================================


stock GetFileNameFromLst( file[], line )
{
	/*  Returns the line in the specified line of the specified file.
	    @file[]:            File to return the line from.
	    @line:              Line number to return.
	*/
	new string[150];

	new CurrLine,
		File:Handler = fopen(file, io_read);

	if(line >= 0 && CurrLine != line)
	{
        while(CurrLine != line)
        {
			fread(Handler, string);
            CurrLine ++;
        }
	}

	// Read the next line, which is the asked one.
	fread(Handler, string);
	fclose(Handler);

	// Cut the last two characters (\n)
	strmid(string, string, 0, strlen(string) - 2, 150);

	return string;
}

stock DeleteLineFromFile( file[], line )
{
	/*  Deletes a specific line from a specific file.
	    @file[]:        File to delete the line from.
	    @line:          Line number to delete.
	*/

	if(line < 0) return false;

	new tmpfile[140];
	format(tmpfile, sizeof(tmpfile), "%s.tmp", file);
	fcopytextfile(file, tmpfile);
	// Copied to a temp file, now parse it back.

	new CurrLine,
		File:FileFrom 	= fopen(tmpfile, io_read),
		File:FileTo		= fopen(file, io_write);

	new tmpstring[200];
	if(CurrLine != line)
	{
		while(CurrLine != line)
		{
		    fread(FileFrom, tmpstring);
			fwrite(FileTo, tmpstring);
			CurrLine ++;
		}
	}

	// Skip a line
	fread(FileFrom, tmpstring);

	// Write the rest
	while(fread(FileFrom, tmpstring))
	{
	    fwrite(FileTo, tmpstring);
	}

	fclose(FileTo);
	fclose(FileFrom);
	// Remove tmp file.
	fremove(tmpfile);
	return true;
}

/** BY DRACOBLUE
 *  Strips Newline from the end of a string.
 *  Idea: Y_Less, Bugfixing (when length=1) by DracoBlue
 *  @param   string
 */
// Function removed - already defined in include files

/** BY DRACOBLUE
 *  Copies a textfile (Source file won't be deleted!)
 *  @param   oldname
 *           newname
 */
// Function removed - already defined in include files

stock RGB( red, green, blue, alpha )
{
	/*  Combines a color and returns it, so it can be used in functions.
	    @red:           Amount of red color.
	    @green:         Amount of green color.
	    @blue:          Amount of blue color.
	    @alpha:         Amount of alpha transparency.

		-Returns:
		A integer with the combined color.
	*/
	// SA-MP expects AARRGGBB
	return (alpha << 24) | (red << 16) | (green << 8) | blue;
}

stock IsNumeric2(const string[])
{
    // Is Numeric Check 2
	// ------------------
	// By DracoBlue... handles negative numbers

	new length=strlen(string);
	if (length==0) return false;
	for (new i = 0; i < length; i++)
	{
	  if((string[i] > '9' || string[i] < '0' && string[i]!='-' && string[i]!='+' && string[i]!='.') // Not a number,'+' or '-' or '.'
	         || (string[i]=='-' && i!=0)                                             // A '-' but not first char.
	         || (string[i]=='+' && i!=0)                                             // A '+' but not first char.
	     ) return false;
	}
	if (length==1 && (string[0]=='-' || string[0]=='+' || string[0]=='.')) return false;
	return true;
}

/** BY DRACOBLUE
 *  Return the value of an hex-string
 *  @param string
 */
// Function removed - already defined in include files

stock IsPlayerMinID(playerid)
{
	/*  Checks if the player is the minumum ID in the server.
	    @playerid:              ID to check.
	    
	    -Returns:
	    true if he is, false if he isn't.
	*/
	for(new i; i < playerid; i ++)
	{
	    if(IsPlayerConnected(i))
	    {
		    if(IsPlayerNPC(i)) continue;
		    else return false;
		}
	}
	return true;
}

stock GetColorGroup(index)
{
	new name[24];
	format(name, sizeof(name), "%s", HTML_COLORS[index][HTMLColorName]);
	// 1: Brancos/Cinzas
	if(strfind(name, "White", true) != -1 || strfind(name, "Smoke", true) != -1 || strfind(name, "Ivory", true) != -1 \
	|| strfind(name, "Gainsboro", true) != -1 || strfind(name, "Grey", true) != -1 || strfind(name, "Gray", true) != -1 \
	|| strfind(name, "Black", true) != -1) return 1;
	// 2: Azuis
	if(strfind(name, "Blue", true) != -1 || strfind(name, "Azure", true) != -1 || strfind(name, "Cyan", true) != -1 \
	|| strfind(name, "Turquoise", true) != -1 || strfind(name, "Sky", true) != -1 || strfind(name, "Navy", true) != -1 \
	|| strfind(name, "Dodger", true) != -1 || strfind(name, "Cornflower", true) != -1 || strfind(name, "Steel", true) != -1 \
	|| strfind(name, "Powder", true) != -1) return 2;
	// 3: Verdes
	if(strfind(name, "Green", true) != -1 || strfind(name, "Olive", true) != -1 || strfind(name, "Sea", true) != -1 \
	|| strfind(name, "Chartreuse", true) != -1 || strfind(name, "Spring", true) != -1 || strfind(name, "Lawn", true) != -1 \
	|| strfind(name, "Forest", true) != -1) return 3;
	// 4: Amarelos/Dourados
	if(strfind(name, "Yellow", true) != -1 || strfind(name, "Gold", true) != -1 || strfind(name, "Goldenrod", true) != -1 \
	|| strfind(name, "Khaki", true) != -1 || strfind(name, "Chiffon", true) != -1) return 4;
	// 5: Marrons/Laranjas
	if(strfind(name, "Brown", true) != -1 || strfind(name, "Sienna", true) != -1 || strfind(name, "Peru", true) != -1 \
	|| strfind(name, "Burlywood", true) != -1 || strfind(name, "Beige", true) != -1 || strfind(name, "Wheat", true) != -1 \
	|| strfind(name, "Sandy", true) != -1 || strfind(name, "Tan", true) != -1 || strfind(name, "Chocolate", true) != -1 \
	|| strfind(name, "Orange", true) != -1 || strfind(name, "Moccasin", true) != -1 || strfind(name, "Papaya", true) != -1 \
	|| strfind(name, "Almond", true) != -1 || strfind(name, "Bisque", true) != -1 || strfind(name, "Peach", true) != -1 \
	|| strfind(name, "Navajo", true) != -1 || strfind(name, "Antique", true) != -1 || strfind(name, "Linen", true) != -1 \
	|| strfind(name, "OldLace", true) != -1 || strfind(name, "FloralWhite", true) != -1) return 5;
	// 6: Vermelhos/Rosas
	if(strfind(name, "Red", true) != -1 || strfind(name, "Pink", true) != -1 || strfind(name, "Salmon", true) != -1 \
	|| strfind(name, "Tomato", true) != -1 || strfind(name, "Coral", true) != -1 || strfind(name, "Firebrick", true) != -1 \
	|| strfind(name, "Maroon", true) != -1 || strfind(name, "IndianRed", true) != -1 || strfind(name, "RosyBrown", true) != -1) return 6;
	// 7: Roxos/Violetas
	if(strfind(name, "Purple", true) != -1 || strfind(name, "Violet", true) != -1 || strfind(name, "Magenta", true) != -1 \
	|| strfind(name, "Orchid", true) != -1 || strfind(name, "Plum", true) != -1 || strfind(name, "Thistle", true) != -1) return 7;
	return 0;
}

stock BuildFilteredSortedIndices(playerid, indices[], maxSize)
{
	new filter[32];
	format(filter, sizeof(filter), "%s", pData[playerid][P_ColorFilter]);
	new group = pData[playerid][P_ColorGroup];
	new count;
	// Normalize a plain 6-digit hex into #RRGGBB for matching
	if(filter[0] && filter[0] != '#')
	{
		new bool:isHex = true;
		new len = strlen(filter);
		if(len == 6)
		{
			for(new h = 0; h < 6; h++)
			{
				new c = filter[h];
				if(!(c >= '0' && c <= '9') && !(c >= 'A' && c <= 'F') && !(c >= 'a' && c <= 'f')) { isHex = false; break; }
			}
			if(isHex)
			{
				new tmp[32];
				format(tmp, sizeof(tmp), "#%s", filter);
				format(filter, sizeof(filter), "%s", tmp);
			}
		}
	}
	for(new i = 0; i < sizeof(HTML_COLORS); i++)
	{
		// Group filter
		if(group > 0 && GetColorGroup(i) != group) continue;
		// Text/HEX filter
		if(filter[0])
		{
			if(filter[0] == '#')
			{
				if(strfind(HTML_COLORS[i][HTMLColorHex], filter, true) == -1) continue;
			}
			else
			{
				// Match either Portuguese or English names
				if(strfind(HTML_COLOR_NAMES_PT[i], filter, true) == -1 && strfind(HTML_COLORS[i][HTMLColorName], filter, true) == -1) continue;
			}
		}
		if(count < maxSize)
		{
			indices[count++] = i;
		}
	}
	if(pData[playerid][P_ColorSortMode] == 1 && count > 1)
	{
		// Simple bubble sort by Portuguese name
		for(new a = 0; a < count - 1; a++)
		{
			for(new b = 0; b < count - a - 1; b++)
			{
				if(strcmp(HTML_COLOR_NAMES_PT[indices[b]], HTML_COLOR_NAMES_PT[indices[b+1]], false) > 0)
				{
					new tmp = indices[b];
					indices[b] = indices[b+1];
					indices[b+1] = tmp;
				}
			}
		}
	}
	return count;
}
// Favorites helpers
stock IsFavoriteColor(playerid, idx)
{
    for(new i = 0; i < pData[playerid][P_FavoriteCount] && i < 20; i++)
    {
        if(pData[playerid][P_Favorites][i] == idx) return 1;
    }
    return 0;
}
stock ToggleFavoriteColor(playerid, idx)
{
    // If exists, remove; else add to front
    for(new i = 0; i < pData[playerid][P_FavoriteCount] && i < 20; i++)
    {
        if(pData[playerid][P_Favorites][i] == idx)
        {
            for(new j = i; j < pData[playerid][P_FavoriteCount]-1 && j < 19; j++)
                pData[playerid][P_Favorites][j] = pData[playerid][P_Favorites][j+1];
            pData[playerid][P_FavoriteCount]--;
            return 1;
        }
    }
    // Add to front
    for(new k = 19; k > 0; k--) pData[playerid][P_Favorites][k] = pData[playerid][P_Favorites][k-1];
    pData[playerid][P_Favorites][0] = idx;
    if(pData[playerid][P_FavoriteCount] < 20) pData[playerid][P_FavoriteCount]++;
    return 1;
}
// ================================================================================================================================
// ----------------------------------------------------- END OF AUXULIAR FUNCTIONS ------------------------------------------------
// ================================================================================================================================

