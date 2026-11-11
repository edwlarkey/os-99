#include "BarPassElement.hpp"
#include <hyprland/src/render/OpenGL.hpp>
#include <hyprland/src/render/Renderer.hpp>
#include "barDeco.hpp"

using namespace Render::GL;

CBarPassElement::CBarPassElement(const CBarPassElement::SBarData& data_) : data(data_) {
    ;
}

std::vector<UP<IPassElement>> CBarPassElement::draw(Render::CRenderContext& ctx) {
    if (barsShuttingDown())
        return {};

    data.deco->renderPass(ctx, ctx.m_data.pMonitor.lock(), data.a);
    return {};
}

bool CBarPassElement::needsLiveBlur(Render::CRenderContext&) {
    static auto PENABLEBLURGLOBAL = CConfigValue<Config::BOOL>("decoration:blur:enabled");

    CHyprColor  color = data.deco->m_bForcedBarColor.value_or(CHyprColor{static_cast<uint64_t>(g_pGlobalState->config.barColor->value())});
    color.a *= data.a;
    const bool SHOULDBLUR = g_pGlobalState->config.barBlur->value() && *PENABLEBLURGLOBAL && color.a < 1.F;

    return SHOULDBLUR;
}

std::optional<CBox> CBarPassElement::boundingBox(Render::CRenderContext& ctx) {
    auto       box     = data.deco->frameBoxGlobal();
    const auto TOOLTIP = data.deco->tooltipBoxGlobal();

    if (TOOLTIP.w > 0 && TOOLTIP.h > 0) {
        const double X0 = std::min(box.x, TOOLTIP.x), Y0 = std::min(box.y, TOOLTIP.y);
        const double X1 = std::max(box.x + box.w, TOOLTIP.x + TOOLTIP.w), Y1 = std::max(box.y + box.h, TOOLTIP.y + TOOLTIP.h);
        box = CBox{X0, Y0, X1 - X0, Y1 - Y0};
    }

    return box.translate(-ctx.m_data.pMonitor->m_position).expand(10);
}

bool CBarPassElement::needsPrecomputeBlur(Render::CRenderContext&) {
    return false;
}
