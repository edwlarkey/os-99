#pragma once

#include <hyprland/src/plugins/PluginAPI.hpp>
#include <hyprland/src/render/Texture.hpp>
#include <hyprland/src/config/values/types/BoolValue.hpp>
#include <hyprland/src/config/values/types/IntValue.hpp>
#include <hyprland/src/config/values/types/StringValue.hpp>
#include <hyprland/src/config/values/types/ColorValue.hpp>
#include <hyprland/src/config/values/types/FontWeightValue.hpp>

#include <optional>

inline HANDLE PHANDLE = nullptr;

struct SHyprButton {
    std::string          cmd     = "";
    bool                 userfg  = false;
    CHyprColor           fgcol   = CHyprColor(0, 0, 0, 0);
    CHyprColor           bgcol   = CHyprColor(0, 0, 0, 0);
    float                size    = 10;
    std::string          icon    = "";
    SP<Render::ITexture> iconTex;
    std::optional<float> m_fIconScale;

    std::string          image   = "";
    SP<Render::ITexture> imageTex;
    uint64_t             imageStamp = UINT64_MAX;

    std::string          dispatch = "";
    std::string          side     = "";
    std::string          tooltip       = "";
    std::string          tooltipActive = "";
    std::string          activeWhen    = "";
    std::string          showWhen      = "";

    SP<Render::ITexture> imagePressedTex;
    uint64_t             imagePressedStamp = UINT64_MAX;
};

class CHyprBar;

struct SGlobalState {
    bool                      shuttingDown = false;
    std::vector<SHyprButton>  buttons;
    std::vector<WP<CHyprBar>> bars;
    uint32_t                  nobarRuleIdx      = 0;
    uint32_t                  barColorRuleIdx   = 0;
    uint32_t                  titleColorRuleIdx = 0;

    struct {
        SP<Config::Values::CColorValue>      barColor, textColor, inactiveButtonColor;
        SP<Config::Values::CIntValue>        barHeight;
        SP<Config::Values::CIntValue>        barTextSize;
        SP<Config::Values::CFontWeightValue> barTextWeight;
        SP<Config::Values::CIntValue>        barPadding;
        SP<Config::Values::CIntValue>        barButtonPadding;
        SP<Config::Values::CBoolValue>       barBlur, barTitleEnabled, barPartOfWindow, barPrecedenceOverBorder, enabled, iconOnHover, buttonsOnHover, barTooltips;
        SP<Config::Values::CStringValue>     barTextFont, barTextAlign, barButtonsAlignment, onDoubleClick, barMenuCommand;
        SP<Config::Values::CStringValue>     barTexture, barTextureBorder;
        SP<Config::Values::CStringValue>     frameTexture, frameTextureBorder, frameInset;
        SP<Config::Values::CColorValue>      barClearColor;
        SP<Config::Values::CBoolValue>       frameTextureUnscaled, frameOverWindow, frameForceSquare, frameForceFlat;
        SP<Config::Values::CIntValue>        barTextClearPad, barButtonClearPad, barTooltipDelay;
        SP<Config::Values::CIntValue>        barClearInsetTop, barClearInsetBottom;
    } config;
};

inline UP<SGlobalState> g_pGlobalState;

inline bool barsShuttingDown() {
    return !g_pGlobalState || g_pGlobalState->shuttingDown;
}
