--
-- lib_RedBand
-- by: Hanachi
--

if RedBand then
	return nil
end

RedBand = {}

local PRIVATE = {}

local Band = [[<Group dimensions="left:0; right:100%; top:0; height:0" style="clip-children:true" depth="-5">
	<StillArt name="panel" dimensions="dock:fill" style="texture:colors; region:white;"/>
	<Text name="title" dimensions="dock:fill" style="font:Demi_15; tint:PanelTitle; halign:center; valign:center; padding:0; clip:true"/>
</Group>]];

-- Constants --

RedBand.open_dur = 5

-- Public Functions

function RedBand.ErrorMessage(string, dur)
	PRIVATE.CreateBand(string, "780505", dur or RedBand.open_dur)
end

function RedBand.GenericMessage(string, dur)
	PRIVATE.CreateBand(string, "6f6f6f", dur or RedBand.open_dur)
end

function RedBand.CustomMessage(string, tint, dur)
	PRIVATE.CreateBand(string, tint or "6f6f6f", dur or RedBand.open_dur)
end

-- Private Functions

function PRIVATE.CreateBand(string, tint, dur)
	if not PARENT then PARENT = Component.CreateFrame("HUDFrame") end

	local WIDGET = Component.CreateWidget(Band, PARENT)

	local REDBAND = {
		GROUP = WIDGET,
		PANEL = WIDGET:GetChild("panel"),
		TITLE = WIDGET:GetChild("title"),
	}

	REDBAND.PANEL:SetParam("tint", tint)

	REDBAND.TITLE:SetText(string)

	REDBAND.GROUP:MoveTo("top:_; height:32", dur/2.5, "ease-in")

	REDBAND.GROUP:QueueMove("top:_; height:0", dur/2.5, dur-(dur/2.5), "ease-out") 
	PRIVATE.Destroy(REDBAND, dur*2)
end

function PRIVATE.Destroy(band, dur)
	callback(function() Component.RemoveWidget(band.GROUP) band = nil end, nil, dur)
end