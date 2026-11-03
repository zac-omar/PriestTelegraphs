-- Priest Telegraphs: ground telegraphs for your hero's spells and their area effects. /tele opens the
-- options.
--
-- How it draws: the client can't project an arbitrary world point, but AZS_ProjectWorldAnchors
-- projects an anchor (an enemy, cache, lair...) plus an offset in yards. Each frame four ground
-- points close around the hero are projected that way; the ground-to-screen mapping of a flat
-- plane through a perspective camera is a homography, so those four fix it exactly and every
-- shape is placed from it without more calls. With no anchor on the map there is nothing to
-- project from, and the telegraphs hide until one shows up.
--
-- Two styles. Smooth fills a shape with thin screen-wide strips and strokes its outline with
-- solid quads; Dots marks it out in round dots.
--
-- Adding a telegraph: add an entry to DEFS. shape "cone" (apex at the hero, along its facing),
-- "circle" (around the hero) or "enemy" (where an effect goes off on an enemy). spellKey is the spell's
-- key in AZS_SPELLS (its cooldown and casts), tipNames the first lines of action bar tooltips
-- to read its size from with sizePattern; base, reachTalent and reachPerRank the fallback
-- formula when no tooltip can be read. Without sizePattern the size is the `radius` setting.

local CAST = { "cast", "Briefly on cast", 100 };
local COOLDOWN = { "cooldown", "Always + cooldown fill", 150 };

local DEFS = {
	{
		id = "mind_flay", name = "Mind Flay", shape = "cone", spellKey = "mind_flay",
		modes = { CAST, COOLDOWN },
		-- The server hits an enemy when dot(facing, direction to it) > 0.5: 60 degrees either side.
		halfAngle = 60,
		tipNames = { "Mind Flay" }, sizePattern = "([%d%.]+) yd cone",
		-- 16 yd x Area x (1 + 10% per Shadow Reach rank); misses Mind Flay's own "+% area" upgrades
		base = 16, reachTalent = "shadow_reach", reachPerRank = 0.10,
		defaults = { mode = "cooldown", line = { 0.75, 0.45, 1, 1 }, fill = { 0.55, 0.25, 0.95, 0.3 } },
	},
	{
		id = "holy_nova", name = "Holy Nova", shape = "circle", spellKey = "holy_nova",
		modes = { CAST, COOLDOWN },
		tipNames = { "Holy Nova" }, sizePattern = "within ([%d%.]+) yd of you",
		-- 10 yd x Area x (1 + 10% per Holy Reach rank). Radiance's and Chastise's free novas are
		-- the same size.
		base = 10, reachTalent = "holy_reach", reachPerRank = 0.10,
		defaults = { mode = "cast", line = { 1, 0.85, 0.35, 1 }, fill = { 1, 0.8, 0.3, 0.3 } },
	},
	{
		id = "psychic_scream", name = "Psychic Scream", shape = "circle", spellKey = "psychic_scream",
		modes = { CAST, COOLDOWN },
		tipNames = { "Psychic Scream" }, sizePattern = "within ([%d%.]+) yd of you",
		base = 10,
		defaults = { mode = "cast", line = { 0.9, 0.35, 0.85, 1 }, fill = { 0.65, 0.2, 0.75, 0.3 } },
	},
	{
		-- Divine Aegis: a shield on you that breaks strikes every enemy within 10 yd (its data's
		-- radius). The Power Word: Shield legendary amulet's burst is 8 yd. Shown only with one.
		id = "shield", name = "Shield burst", shape = "circle", buffSpells = { 17, 592, 600, 3747, 6065, 6066, 10898, 10899, 10900, 10901 },
		match = { "divineaegis", "item/pwshield" }, radii = { divineaegis = 10, ["item/pwshield"] = 8 },
		needName = "Divine Aegis or the Power Word: Shield amulet",
		defaults = { mode = "shield", line = { 1, 1, 0.65, 1 }, fill = { 1, 1, 0.75, 0.12 } },
	},
	{
		-- How far your targeted spells look for enemies.
		id = "range", name = "Spell range", shape = "circle",
		tipNames = { "Smite", "Mind Blast", "Holy Fire", "Shadow Word: Pain", "Devouring Plague" },
		sizePattern = "within ([%d%.]+) yd", base = 28,
		defaults = { enabled = false, mode = "always", line = { 0.55, 0.8, 1, 0.6 }, fill = { 0.55, 0.8, 1, 0 } },
	},
	-- Effects around enemies, drawn where they go off. Each is shown only while your hero has
	-- it: its talent or amulet in the run's loadout, or its own damage seen in the combat text.
	-- `match` are the loadout keys that give it, `needs` the damage-over-time an enemy must die
	-- with (per matched key), `cap` its "at most N times a second".
	{
		-- "Enemies you kill explode for 15% of their max health, at most 4 times a second" (6 yd,
		-- its data)
		id = "choker", name = "Choker of the Fire Lord", shape = "enemy", trigger = "kill", cap = 4,
		match = { "chokerofthefirelord", "firelord" }, radius = 6,
		defaults = { mode = "event", flash = 0.5, line = { 1, 0.45, 0.2, 1 }, fill = { 1, 0.35, 0.1, 0.25 } },
	},
	{
		-- "Enemies that die with Shadow Word: Pain (or Devouring Plague) on them explode for 20% of
		-- their max health, at most 2 times a second". No radius anywhere: the game's other death
		-- explosions are 6 yd.
		id = "pendant", name = "Pendant of the Plague", shape = "enemy", trigger = "kill", cap = 2,
		match = { "item/swpain", "item/devouringplague", "pendantoftheplague" },
		needs = { ["item/swpain"] = "swp", ["item/devouringplague"] = "dp", pendantoftheplague = "any" },
		radius = 6,
		defaults = { mode = "event", flash = 0.5, line = { 0.55, 1, 0.35, 1 }, fill = { 0.4, 0.9, 0.2, 0.25 } },
	},
	{
		-- Shadowform (capstone): "when an enemy dies with Shadow Word: Pain on it, it bursts for 4%
		-- of its maximum health on everything within 6 yd"
		id = "shadowform", name = "Shadowform burst", shape = "enemy", trigger = "kill",
		match = { "shadowform" }, needs = { shadowform = "swp" }, radius = 6,
		defaults = { mode = "event", flash = 0.5, line = { 0.6, 0.35, 1, 1 }, fill = { 0.45, 0.2, 0.8, 0.25 } },
	},
	{
		-- "Your critical hits splash 30% on enemies within 5 yd, at most 6 times a second"
		id = "onyxia", name = "Onyxia Tooth Pendant", shape = "enemy", trigger = "crit", cap = 6,
		match = { "onyxiatoothpendant", "onyxiatooth" }, radius = 5,
		defaults = { mode = "event", flash = 0.4, line = { 0.6, 0.9, 1, 1 }, fill = { 0.5, 0.8, 1, 0.2 } },
	},
	{
		id = "ring", name = "Custom ring", shape = "circle",
		defaults = { enabled = false, mode = "always", radius = 8, line = { 1, 0.25, 0.25, 1 }, fill = { 1, 0.25, 0.25, 0 } },
	},
}

local COMMON = {
	enabled = true, mode = "cooldown", style = "smooth", flash = 0.6,
	line = { 1, 1, 1, 1 }, fill = { 1, 1, 1, 0.3 },
	width = 3, glow = true, strip = 3,                                     -- Smooth
	size = 5, spacing = 9, fillSpacing = 12, fillStyle = "solid",          -- Dots
	length = 0, radius = 8,
	most = 0,                                                              -- enemy effects: 0 = no cap
};

local TEX = "Interface\\AddOns\\PriestTelegraphs\\Textures\\";
local SOLID, ROUND = TEX .. "solid", TEX .. "dot";
local MAX_QUADS = 4000;
local MAX_FILL_DOTS = 600;
local MAX_STRIPS = 400;
local SOFT_CAP = 70;
local PI = 3.14159265;
local PAD = 50;            -- how far past the screen's edge a shape is still drawn

-- Static anchors first: their position never changes, so the offset can't drift.
local PRIORITY = { cache = 1, guardianLair = 2, guardian = 3, boss = 4, finalBoss = 5, elite = 6, enemy = 7 };
local KINDS = { "cache", "guardianLair", "guardian", "boss", "finalBoss", "elite", "enemy" };
local STATIC = { cache = true, guardianLair = true };

local db;
local byId = {};
for i = 1, table.getn(DEFS) do
	byId[DEFS[i].id] = DEFS[i];
end

local function Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cffb080ffPriest Telegraphs|r: " .. msg);
end

local function Copy(v)
	if ( type(v) ~= "table" ) then
		return v;
	end
	local t = {};
	for k, x in pairs(v) do
		t[k] = Copy(x);
	end
	return t;
end

local function ErrText(err)
	if ( type(err) == "table" ) then
		return tostring(err.code) .. ": " .. tostring(err.message);
	end
	return tostring(err);
end

local function Entries(res, key)
	if ( type(res) ~= "table" ) then
		return nil;
	end
	if ( type(res[key or "entries"]) == "table" ) then
		return res[key or "entries"];
	end
	return res;
end

-- A telegraph's settings, its defaults filled in.
local function Settings(def)
	local s = db.t[def.id];
	if ( not s ) then
		s = {};
		db.t[def.id] = s;
	end
	for k, v in pairs(COMMON) do
		if ( s[k] == nil ) then
			if ( def.defaults and def.defaults[k] ~= nil ) then
				s[k] = Copy(def.defaults[k]);
			else
				s[k] = Copy(v);
			end
		end
	end
	return s;
end

local function ResetSettings(def)
	db.t[def.id] = nil;
	return Settings(def);
end

---------------------------------------------------------------------------------------------
-- Quads: every dot, strip and outline piece is one texture from this pool

local canvas = CreateFrame("Frame", "PriestTelegraphsCanvas", WorldFrame);
canvas:SetAllPoints(WorldFrame);
canvas:SetFrameStrata("BACKGROUND");

local pool, used, shown = {}, 0, 0;
local screenW, screenH = 1024, 768;

local function Quad(tex, x, y, w, h, c, alpha)
	if ( used >= MAX_QUADS or x > screenW + PAD or y > screenH + PAD or x + w < -PAD or y + h < -PAD ) then
		return;
	end
	used = used + 1;
	local t = pool[used];
	if ( not t ) then
		t = canvas:CreateTexture(nil, "OVERLAY");
		pool[used] = t;
	end
	if ( t.tex ~= tex ) then
		t:SetTexture(tex);
		t.tex = tex;
	end
	local a = c[4] * alpha;
	if ( a > 1 ) then
		a = 1;
	end
	if ( t.r ~= c[1] or t.g ~= c[2] or t.b ~= c[3] or t.a ~= a ) then
		t:SetVertexColor(c[1], c[2], c[3], a);
		t.r, t.g, t.b, t.a = c[1], c[2], c[3], a;
	end
	if ( t.w ~= w ) then
		t:SetWidth(w);
		t.w = w;
	end
	if ( t.h ~= h ) then
		t:SetHeight(h);
		t.h = h;
	end
	t:ClearAllPoints();
	t:SetPoint("BOTTOMLEFT", WorldFrame, "BOTTOMLEFT", x, y);
	if ( not t.on ) then
		t:Show();
		t.on = true;
	end
end

local function FinishQuads()
	for i = used + 1, shown do
		local t = pool[i];
		if ( t and t.on ) then
			t:Hide();
			t.on = false;
		end
	end
	shown = used;
	used = 0;
end

---------------------------------------------------------------------------------------------
-- Ground to screen

local H = {};          -- the homography: yards from the hero (u, v) -> WorldFrame offsets
local scale = 10;      -- screen units per yard at the hero
local anchor;          -- the entry projected from
local requests = {};
local lastError;

local function PickAnchor(p)
	local res, err = AZS_GetWorldAnchors({ kinds = KINDS }, nil, 64);
	if ( not res ) then
		res, err = AZS_GetWorldAnchors(nil, nil, 64);
	end
	local list = Entries(res);
	if ( not list ) then
		lastError = "anchor query: " .. ErrText(err);
		return nil;
	end
	local best, bestRank;
	for i = 1, table.getn(list) do
		local e = list[i];
		if ( type(e) == "table" and e.anchorId and e.positionAvailable ~= false
			and type(e.x) == "number" and type(e.y) == "number" and type(e.z) == "number"
			and ( e.spaceId == nil or p.spaceId == nil or e.spaceId == p.spaceId ) ) then
			local rank = PRIORITY[e.kind] or 99;
			if ( not best or rank < bestRank ) then
				best, bestRank = e, rank;
			end
		end
	end
	if ( not best ) then
		lastError = "no anchor with a position on this map yet";
		return nil;
	end
	return { anchorId = best.anchorId, kind = best.kind, x = best.x, y = best.y, z = best.z };
end

-- Solves the 8x8 system a * h = b (a has b as its 9th column) by elimination.
local function Solve(a)
	for col = 1, 8 do
		local pivot, best = col, math.abs(a[col][col]);
		for row = col + 1, 8 do
			if ( math.abs(a[row][col]) > best ) then
				pivot, best = row, math.abs(a[row][col]);
			end
		end
		if ( best < 1e-9 ) then
			return nil;
		end
		a[col], a[pivot] = a[pivot], a[col];
		for row = 1, 8 do
			if ( row ~= col ) then
				local f = a[row][col] / a[col][col];
				if ( f ~= 0 ) then
					for k = col, 9 do
						a[row][k] = a[row][k] - f * a[col][k];
					end
				end
			end
		end
	end
	local h = {};
	for i = 1, 8 do
		h[i] = a[i][9] / a[i][i];
	end
	return h;
end

local function Map(u, v)
	local w = H[7] * u + H[8] * v + 1;
	if ( w <= 1e-4 ) then
		return nil;   -- past the horizon
	end
	return (H[1] * u + H[2] * v + H[3]) / w, (H[4] * u + H[5] * v + H[6]) / w;
end

-- A screen point back on the ground at the hero's height.
local function Unmap(x, y)
	local a, b, c = H[1] - x * H[7], H[2] - x * H[8], x - H[3];
	local d, e, f = H[4] - y * H[7], H[5] - y * H[8], y - H[6];
	local det = a * e - b * d;
	if ( math.abs(det) < 1e-9 ) then
		return nil;
	end
	return (c * e - b * f) / det, (a * f - c * d) / det;
end

local CORNERS = { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } };
-- How far out the four points go, in yards. The game gives no screen position for a point off
-- the screen, so they stay close to the hero: the mapping they fix holds for the whole ground
-- anyway. Closer still if the camera is zoomed in so far that even these are off it.
local SPANS = { 5, 2.5, 1.25 };
-- states that are the point's, not the anchor's: a smaller span may fix them
local OFF_VIEW = { offscreen = true, clipped = true, behindCamera = true };

-- The four points `s` yards around the hero, projected: their entries, or nil and whether the
-- anchor itself failed.
local function ProjectCorners(p, s)
	local dx, dy, dz = p.x - anchor.x, p.y - anchor.y, p.z - anchor.z;
	for i = 1, 4 do
		local r = requests[i];
		if ( not r ) then
			r = { attachment = "position", offset = {} };
			requests[i] = r;
		end
		r.anchorId = anchor.anchorId;
		r.offset.x = dx + CORNERS[i][1] * s;
		r.offset.y = dy + CORNERS[i][2] * s;
		r.offset.z = dz;
	end
	local res, err = AZS_ProjectWorldAnchors(requests);
	local list = Entries(res);
	if ( not list ) then
		lastError = "projection: " .. ErrText(err);
		return nil, true;
	end
	for i = 1, 4 do
		local e = list[i];
		if ( type(e) ~= "table" or type(e.x) ~= "number" or type(e.y) ~= "number" or e.state == "behindCamera" ) then
			local state = type(e) == "table" and e.state;
			lastError = string.format("point %g yd from you gave no screen position (state %s, reason %s)",
				s, tostring(state), tostring(type(e) == "table" and e.reason));
			return nil, not OFF_VIEW[state];
		end
	end
	return list, false;
end

-- Fixes H for this frame from four ground points projected around the hero.
local function BuildMap(p)
	if ( not anchor or not STATIC[anchor.kind] ) then
		anchor = PickAnchor(p);
	end
	if ( not anchor ) then
		return false;
	end
	local list, s;
	for i = 1, table.getn(SPANS) do
		s = SPANS[i];
		local anchorFailed;
		list, anchorFailed = ProjectCorners(p, s);
		if ( list ) then
			break;
		elseif ( anchorFailed ) then
			-- the anchor went away (cache opened, enemy died, new map): another one next frame
			anchor = nil;
			return false;
		end
	end
	if ( not list ) then
		return false;
	end
	local a = {};
	for i = 1, 4 do
		local e = list[i];
		local u, v = CORNERS[i][1] * s, CORNERS[i][2] * s;
		a[2 * i - 1] = { u, v, 1, 0, 0, 0, -u * e.x, -v * e.x, e.x };
		a[2 * i] = { 0, 0, 0, u, v, 1, -u * e.y, -v * e.y, e.y };
	end
	local h = Solve(a);
	if ( not h ) then
		lastError = "the projected points were degenerate";
		return false;
	end
	H = h;
	local x0, y0 = Map(0, 0);
	local x1, y1 = Map(1, 0);
	local x2, y2 = Map(0, 1);
	if ( not x0 or not x1 or not x2 ) then
		return false;
	end
	scale = (math.sqrt((x1 - x0) * (x1 - x0) + (y1 - y0) * (y1 - y0))
		+ math.sqrt((x2 - x0) * (x2 - x0) + (y2 - y0) * (y2 - y0))) / 2;
	lastError = nil;
	return true;
end

-- The world angle that points up the screen, and the sign that turns clockwise on it.
local function ScreenUp()
	local x0, y0 = Map(0, 0);
	local best, bestY = 0, nil;
	for i = 0, 63 do
		local a = i * 2 * PI / 64;
		local x, y = Map(math.cos(a), math.sin(a));
		if ( x and ( not bestY or y - y0 > bestY ) ) then
			best, bestY = a, y - y0;
		end
	end
	local xa, ya = Map(math.cos(best), math.sin(best));
	local xb, yb = Map(math.cos(best + 0.1), math.sin(best + 0.1));
	local turn = -1;
	if ( xa and xb and (xa - x0) * (yb - y0) - (ya - y0) * (xb - x0) < 0 ) then
		turn = 1;   -- a growing angle already turns clockwise on screen
	end
	return best, turn;
end

---------------------------------------------------------------------------------------------
-- Smooth: polygons on screen, filled with strips and stroked with quads

local PX, PY, PN = {}, {}, 0;

local function Add(u, v)
	local x, y = Map(u, v);
	if ( not x ) then
		return false;
	end
	PN = PN + 1;
	PX[PN], PY[PN] = x, y;
	return true;
end

-- Points along an arc around (cu, cv), one every few screen units.
local function AddArc(cu, cv, r, a0, a1)
	local n = math.ceil(r * math.abs(a1 - a0) * scale / 5);
	if ( n < 4 ) then
		n = 4;
	elseif ( n > 128 ) then
		n = 128;
	end
	for i = 0, n do
		local a = a0 + (a1 - a0) * i / n;
		if ( not Add(cu + r * math.cos(a), cv + r * math.sin(a)) ) then
			return false;
		end
	end
	return true;
end

local BK = {};

-- Fills the polygon PX/PY (even-odd) with horizontal strips `strip` units tall.
local function FillPoly(c, alpha, strip)
	if ( PN < 3 or c[4] * alpha <= 0.003 ) then
		return;
	end
	local ymin, ymax = PY[1], PY[1];
	for i = 2, PN do
		local y = PY[i];
		if ( y < ymin ) then
			ymin = y;
		elseif ( y > ymax ) then
			ymax = y;
		end
	end
	if ( ymin < 0 ) then
		ymin = 0;
	end
	if ( ymax > screenH ) then
		ymax = screenH;
	end
	if ( ymax <= ymin ) then
		return;
	end
	local s = strip;
	if ( (ymax - ymin) / s > MAX_STRIPS ) then
		s = (ymax - ymin) / MAX_STRIPS;
	end
	local k0, k1 = math.floor(ymin / s), math.floor(ymax / s);
	for k = 1, k1 - k0 + 1 do
		local b = BK[k];
		if ( b ) then
			b.n = 0;
		else
			BK[k] = { n = 0 };
		end
	end
	for i = 1, PN do
		local j = i + 1;
		if ( j > PN ) then
			j = 1;
		end
		local x1, y1, x2, y2 = PX[i], PY[i], PX[j], PY[j];
		if ( y1 ~= y2 ) then
			if ( y1 > y2 ) then
				x1, y1, x2, y2 = x2, y2, x1, y1;
			end
			-- the strips whose middle, (k + 0.5) s, lies in [y1, y2)
			local ka, kb = math.ceil(y1 / s - 0.5), math.ceil(y2 / s - 0.5) - 1;
			if ( ka < k0 ) then
				ka = k0;
			end
			if ( kb > k1 ) then
				kb = k1;
			end
			local slope = (x2 - x1) / (y2 - y1);
			for k = ka, kb do
				local b = BK[k - k0 + 1];
				b.n = b.n + 1;
				b[b.n] = x1 + ((k + 0.5) * s - y1) * slope;
			end
		end
	end
	for k = k0, k1 do
		local b = BK[k - k0 + 1];
		local n = b.n;
		if ( n >= 2 ) then
			for i = 2, n do
				local v, j = b[i], i - 1;
				while ( j >= 1 and b[j] > v ) do
					b[j + 1] = b[j];
					j = j - 1;
				end
				b[j + 1] = v;
			end
			for i = 1, n - 1, 2 do
				local xa, xb = b[i], b[i + 1];
				if ( xa < -PAD ) then
					xa = -PAD;
				end
				if ( xb > screenW + PAD ) then
					xb = screenW + PAD;
				end
				if ( xb > xa ) then
					Quad(SOLID, xa, k * s, xb - xa, s, c, alpha);
				end
			end
		end
	end
end

-- One stroke piece from (x1, y1) to (x2, y2), `w` wide, as runs of quads along its long axis.
-- Each run climbs at most 3 units, so a thick stroke's edge is as fine as a thin one's.
local function Segment(x1, y1, x2, y2, c, alpha, w, cap1, cap2)
	local dx, dy = x2 - x1, y2 - y1;
	local hw = w * 0.5;
	local rise = math.min(w, 3);
	if ( math.abs(dx) >= math.abs(dy) ) then
		if ( dx < 0 ) then
			x1, y1, x2, y2, dx, dy, cap1, cap2 = x2, y2, x1, y1, -dx, -dy, cap2, cap1;
		end
		local n = math.ceil(math.abs(dy) / rise);
		if ( n < 1 ) then
			n = 1;
		end
		for i = 0, n - 1 do
			local xa, xb = x1 + dx * i / n, x1 + dx * (i + 1) / n;
			if ( i == 0 and cap1 ) then
				xa = xa - hw;
			end
			if ( i == n - 1 and cap2 ) then
				xb = xb + hw;
			end
			Quad(SOLID, xa, y1 + dy * (i + 0.5) / n - hw, xb - xa, w, c, alpha);
		end
	else
		if ( dy < 0 ) then
			x1, y1, x2, y2, dx, dy, cap1, cap2 = x2, y2, x1, y1, -dx, -dy, cap2, cap1;
		end
		local n = math.ceil(math.abs(dx) / rise);
		if ( n < 1 ) then
			n = 1;
		end
		for i = 0, n - 1 do
			local ya, yb = y1 + dy * i / n, y1 + dy * (i + 1) / n;
			if ( i == 0 and cap1 ) then
				ya = ya - hw;
			end
			if ( i == n - 1 and cap2 ) then
				yb = yb + hw;
			end
			Quad(SOLID, x1 + dx * (i + 0.5) / n - hw, ya, w, yb - ya, c, alpha);
		end
	end
end

-- Is the turn at point i sharp enough to need its corner covered?
local function Sharp(i, closed)
	local p, n = i - 1, i + 1;
	if ( p < 1 ) then
		if ( not closed ) then
			return true;
		end
		p = PN;
	end
	if ( n > PN ) then
		if ( not closed ) then
			return true;
		end
		n = 1;
	end
	local ax, ay, bx, by = PX[i] - PX[p], PY[i] - PY[p], PX[n] - PX[i], PY[n] - PY[i];
	local la, lb = math.sqrt(ax * ax + ay * ay), math.sqrt(bx * bx + by * by);
	if ( la < 1e-6 or lb < 1e-6 ) then
		return false;
	end
	return (ax * bx + ay * by) / (la * lb) < 0.8;
end

-- Strokes the polyline PX/PY (closed: back to its first point).
local function Stroke(closed, c, alpha, w)
	if ( PN < 2 or c[4] * alpha <= 0.003 ) then
		return;
	end
	local last = PN - 1;
	if ( closed ) then
		last = PN;
	end
	for i = 1, last do
		local j = i + 1;
		if ( j > PN ) then
			j = 1;
		end
		Segment(PX[i], PY[i], PX[j], PY[j], c, alpha, w, Sharp(i, closed), Sharp(j, closed));
	end
end

-- Outline with its glow under it.
local function Outline(closed, st, alpha, wide)
	local w = st.width * (wide or 1);
	if ( st.glow ) then
		Stroke(closed, st.line, alpha * 0.22, w * 3);
	end
	Stroke(closed, st.line, alpha, w);
end

local function Bright(c)
	return { math.min(1, c[1] * 0.4 + 0.6), math.min(1, c[2] * 0.4 + 0.6), math.min(1, c[3] * 0.4 + 0.6), 1 };
end

---------------------------------------------------------------------------------------------
-- Dots

local function Dot(x, y, c, alpha, size)
	Quad(ROUND, x - size / 2, y - size / 2, size, size, c, alpha);
end

local function DotArc(cu, cv, r, a0, a1, c, alpha, size, spacing)
	if ( r <= 0 ) then
		return;
	end
	local n = math.ceil(r * math.abs(a1 - a0) * scale / spacing);
	if ( n < 2 ) then
		n = 2;
	end
	for i = 0, n do
		local a = a0 + (a1 - a0) * i / n;
		local x, y = Map(cu + r * math.cos(a), cv + r * math.sin(a));
		if ( x ) then
			Dot(x, y, c, alpha, size);
		end
	end
end

local function DotRay(r, a, c, alpha, st)
	local n = math.ceil(r * scale / st.spacing);
	local ca, sa = math.cos(a), math.sin(a);
	for i = 1, n do
		local d = r * i / n;
		local x, y = Map(d * ca, d * sa);
		if ( x ) then
			Dot(x, y, c, alpha, st.size);
		end
	end
end

-- Concentric arcs from the middle out to `front`: the Dots style's fill.
local function DotFill(cu, cv, front, a0, a1, st, alpha)
	-- a filled sector of radius R at spacing s takes about angle * (R / s)^2 / 2 dots: widen the
	-- spacing when zoomed in, so the fill stays under MAX_FILL_DOTS
	local spacing = math.max(st.fillSpacing, front * scale * math.sqrt(math.abs(a1 - a0) / 2 / MAX_FILL_DOTS));
	if ( st.fillStyle == "solid" ) then
		local step = spacing / scale;
		local r = step;
		while ( r < front - step * 0.5 ) do
			DotArc(cu, cv, r, a0, a1, st.fill, alpha, st.size, spacing);
			r = r + step;
		end
	end
	DotArc(cu, cv, front, a0, a1, Bright(st.fill), alpha, st.size, st.spacing);
end

---------------------------------------------------------------------------------------------
-- Telegraphs

-- job: def, st, alpha, size, facing, progress (0..1, the cooldown), since (seconds since a cast)
local function DrawCone(job)
	local st, alpha, L = job.st, job.alpha, job.size;
	local h = job.def.halfAngle * PI / 180;
	local a0, a1 = job.facing - h, job.facing + h;
	local p = job.progress;
	local pulse = 0;
	if ( job.since and job.since < 0.35 ) then
		pulse = 1 - job.since / 0.35;
	end
	if ( st.style == "dots" ) then
		local x, y = Map(0, 0);
		if ( x ) then
			Dot(x, y, st.line, alpha, st.size);
		end
		DotRay(L, a0, st.line, alpha, st);
		DotRay(L, a1, st.line, alpha, st);
		DotArc(0, 0, L, a0, a1, st.line, alpha, st.size, st.spacing);
		if ( p and p > 0 ) then
			DotFill(0, 0, L * p, a0, a1, st, alpha);
		end
		return;
	end
	if ( p ) then
		-- what is still to fill, faint (the band from the fill's front out); what has filled, full
		if ( p < 1 ) then
			PN = 0;
			local ok = AddArc(0, 0, L, a0, a1);
			if ( ok and p > 0 ) then
				ok = AddArc(0, 0, L * p, a1, a0);
			elseif ( ok ) then
				ok = Add(0, 0);
			end
			if ( ok ) then
				FillPoly(st.fill, alpha * 0.35, st.strip);
			end
		end
		PN = 0;
		if ( p > 0 and Add(0, 0) and AddArc(0, 0, L * p, a0, a1) ) then
			FillPoly(st.fill, alpha * (1 + pulse), st.strip);
		end
	else
		PN = 0;
		if ( Add(0, 0) and AddArc(0, 0, L, a0, a1) ) then
			FillPoly(st.fill, alpha * (1 + pulse), st.strip);
		end
	end
	PN = 0;
	if ( Add(0, 0) and AddArc(0, 0, L, a0, a1) ) then
		Outline(true, st, alpha, 1 + pulse * 0.6);
	end
	if ( p and p > 0 and p < 1 ) then
		PN = 0;
		if ( AddArc(0, 0, L * p, a0, a1) ) then
			Stroke(false, Bright(st.fill), alpha, st.width);
		end
	end
end

-- A ring at (cu, cv) yards from the hero: filled, outlined, `progress` sweeping round it.
local function DrawCircleAt(cu, cv, R, st, alpha, p, since, up, turn)
	local pulse = 0;
	if ( since and since < 0.35 ) then
		pulse = 1 - since / 0.35;
	end
	if ( st.style == "dots" ) then
		DotArc(cu, cv, R, 0, 2 * PI, st.line, alpha, st.size, st.spacing);
		if ( p and p > 0 ) then
			DotFill(cu, cv, R * p, 0, 2 * PI, st, alpha);
		elseif ( not p and st.fill[4] > 0 ) then
			DotFill(cu, cv, R, 0, 2 * PI, st, alpha * 0.5);
		end
		if ( since and since < 0.4 ) then
			DotArc(cu, cv, R * (0.3 + 0.7 * since / 0.4), 0, 2 * PI, Bright(st.line), alpha * (1 - since / 0.4), st.size, st.spacing);
		end
		return;
	end
	if ( p ) then
		local sweep = 2 * PI * p * turn;
		PN = 0;
		if ( p < 1 and Add(cu, cv) and AddArc(cu, cv, R, up + sweep, up + 2 * PI * turn) ) then
			FillPoly(st.fill, alpha * 0.35, st.strip);
		end
		PN = 0;
		if ( p > 0 and Add(cu, cv) and AddArc(cu, cv, R, up, up + sweep) ) then
			FillPoly(st.fill, alpha * (1 + pulse), st.strip);
		end
		-- the clock hand
		PN = 0;
		if ( p > 0 and p < 1 and Add(cu, cv) and Add(cu + R * math.cos(up + sweep), cv + R * math.sin(up + sweep)) ) then
			Stroke(false, Bright(st.fill), alpha, st.width);
		end
	else
		PN = 0;
		if ( AddArc(cu, cv, R, 0, 2 * PI) ) then
			FillPoly(st.fill, alpha * (1 + pulse), st.strip);
		end
	end
	PN = 0;
	if ( AddArc(cu, cv, R, 0, 2 * PI) ) then
		Outline(true, st, alpha, 1 + pulse * 0.6);
	end
	-- a cast: a shockwave runs out to the edge
	if ( since and since < 0.4 ) then
		PN = 0;
		if ( AddArc(cu, cv, R * (0.3 + 0.7 * since / 0.4), 0, 2 * PI) ) then
			Stroke(true, Bright(st.line), alpha * (1 - since / 0.4), st.width * 1.5);
		end
	end
end

---------------------------------------------------------------------------------------------
-- Sizes: the action bar tooltip first (it has every bonus), the formula if it can't be read

local made, scan = pcall(CreateFrame, "GameTooltip", "PriestTelegraphsScanTip", nil);
if ( not made ) then
	scan = nil;
end
for i = 1, 30 do
	if ( scan and not getglobal("PriestTelegraphsScanTipTextLeft" .. i) ) then
		local l = scan:CreateFontString("PriestTelegraphsScanTipTextLeft" .. i, "ARTWORK", "GameFontNormal");
		local r = scan:CreateFontString("PriestTelegraphsScanTipTextRight" .. i, "ARTWORK", "GameFontNormal");
		if ( scan.AddFontStrings ) then
			pcall(scan.AddFontStrings, scan, l, r);
		end
	end
end

-- A tooltip's lines, as scan[method](a, b) fills it: SetAction(slot), SetInventoryItem("player", slot)...
local function TipLines(method, a, b)
	if ( not scan or not scan[method] ) then
		return nil;
	end
	scan:SetOwner(WorldFrame, "ANCHOR_NONE");
	scan:ClearLines();
	local ok = pcall(scan[method], scan, a, b);
	if ( not ok ) then
		return nil;
	end
	local lines = {};
	local n = scan.NumLines and scan:NumLines() or 30;
	for i = 1, n do
		local fs = getglobal("PriestTelegraphsScanTipTextLeft" .. i);
		local text = fs and fs:GetText();
		if ( text ) then
			table.insert(lines, text);
		end
	end
	scan:Hide();
	return lines;
end

local function ScanAction(slot)
	return TipLines("SetAction", slot);
end

local tipSize = {};    -- by id: { value, slot }
local nextFullScan = {};

local function ReadSize(def, now)
	local c = tipSize[def.id];
	if ( not c ) then
		c = {};
		tipSize[def.id] = c;
	end
	local function TryRead(slot)
		if ( HasAction and not HasAction(slot) ) then
			return false;
		end
		local lines = ScanAction(slot);
		if ( not lines or not lines[1] ) then
			return false;
		end
		local mine = false;
		for i = 1, table.getn(def.tipNames) do
			if ( lines[1] == def.tipNames[i] ) then
				mine = true;
			end
		end
		if ( not mine ) then
			return false;
		end
		for i = 2, table.getn(lines) do
			local _, _, v = string.find(lines[i], def.sizePattern);
			if ( v and tonumber(v) ) then
				c.value, c.slot = tonumber(v), slot;
				return true;
			end
		end
		return false;
	end
	if ( c.slot and TryRead(c.slot) ) then
		return;
	end
	c.slot = nil;
	if ( now < (nextFullScan[def.id] or 0) ) then
		return;
	end
	nextFullScan[def.id] = now + 5;
	for slot = 1, 120 do
		if ( TryRead(slot) ) then
			return;
		end
	end
	-- not on the bar any more: the formula takes over
	c.value = nil;
end

local talents = { at = -100 };

local function TalentRank(key, now)
	if ( not key or type(AZS_GetMeterLoadout) ~= "function" or type(AZS_GetMeterContext) ~= "function" ) then
		return 0;
	end
	if ( now - talents.at > 10 ) then
		talents = { at = now };
		local ctx = AZS_GetMeterContext();
		local l = ctx and ctx.runId and AZS_GetMeterLoadout({ apiVersion = 1, runId = ctx.runId });
		if ( type(l) == "table" and type(l.talents) == "table" ) then
			for i = 1, table.getn(l.talents) do
				local t = l.talents[i];
				local s = type(l.sources) == "table" and l.sources[t.sourceKey];
				local k = (type(s) == "table" and s.talentKey) or t.sourceKey;
				if ( k ) then
					talents[k] = t.rank or 0;
				end
			end
		end
	end
	for k, rank in pairs(talents) do
		if ( k ~= "at" and type(k) == "string" and string.find(k, key, 1, true) ) then
			return rank;
		end
	end
	return 0;
end

-- A telegraph's size in yards and where it came from. `has` is the key that gives an effect,
-- for effects whose size depends on which one it is; `stated` the radius its item's text gives.
local function SizeOf(def, st, now, has, stated)
	if ( not def.sizePattern and not def.radius and not def.radii ) then
		return st.radius, "your setting";
	end
	if ( st.length and st.length > 0 ) then
		return st.length, "your override";
	end
	if ( stated ) then
		return stated, "item text";
	elseif ( def.radii ) then
		return def.radii[has] or 10, "game data";
	elseif ( def.radius ) then
		return def.radius, "game data";
	end
	local c = tipSize[def.id];
	if ( c and c.value ) then
		return c.value, "tooltip";
	end
	local area = (AZS_STATS and tonumber(AZS_STATS.area)) or 1;
	local l = def.base * area * (1 + (def.reachPerRank or 0) * TalentRank(def.reachTalent, now));
	if ( l > SOFT_CAP ) then
		l = SOFT_CAP + 10 * math.log(1 + (l - SOFT_CAP) / 10);
	end
	return l, "formula";
end

---------------------------------------------------------------------------------------------
-- Cooldowns and casts, off the server's AZSSPELLS line ({ key, spell, rank, cd, cdmax })

local cds = {};        -- by spell key: { left, max, castAt, up, down, lineCd, lineAt }
local lastLine, lastRun;
local spellKeys = "none yet";   -- the keys the last line listed, for the options window

-- "mind_flay", "Mind Flay" and "mindflay" are the same spell.
local function Norm(k)
	return string.lower((string.gsub(tostring(k or ""), "[^%w]", "")));
end

local function SpellOf(def)
	if ( not def.spellKey ) then
		return nil;
	end
	return cds[Norm(def.spellKey)] or cds[Norm(def.name)];
end

local function UpdateCooldowns(now, dt, playing)
	-- A new run starts with whatever spells it rolled: nothing carries over, and the spells line
	-- is read again, as it may have come just before the run did.
	local run = AZS_ZONE and AZS_ZONE.run;
	if ( run ~= lastRun ) then
		lastRun = run;
		cds = {};
		lastLine = nil;
	end
	if ( AZS_SPELLS_UPDATED and AZS_SPELLS_UPDATED ~= lastLine ) then
		lastLine = AZS_SPELLS_UPDATED;
		local list = AZS_SPELLS or {};
		local have, keys = {}, {};
		for i = 1, table.getn(list) do
			local e = list[i];
			table.insert(keys, tostring(e.key) .. " r" .. tostring(e.rank));
			local cd, mx = tonumber(e.cd), tonumber(e.cdmax);
			if ( e.key and cd and mx and mx > 0 and (tonumber(e.rank) or 1) > 0 ) then
				local key = Norm(e.key);
				have[key] = true;
				local c = cds[key];
				if ( not c ) then
					c = { up = 0, down = 0 };
					cds[key] = c;
				end
				-- Which way does `cd` run? Between two close lines it moves with the clock: down if it
				-- is the time left (the usual), up if it is the time gone.
				if ( c.lineCd and now - c.lineAt < 1.5 ) then
					local d, t = cd - c.lineCd, now - c.lineAt;
					if ( d < -0.02 and math.abs(-d - t) < 0.3 ) then
						c.down = c.down + 1;
					elseif ( d > 0.02 and math.abs(d - t) < 0.3 ) then
						c.up = c.up + 1;
					end
				end
				c.lineCd, c.lineAt = cd, now;
				local left = cd;
				if ( c.up > c.down + 3 ) then
					left = mx - cd;
				end
				if ( c.left and left > c.left + 0.25 ) then
					-- the cooldown started again: a cast (unless the local clock already called it)
					if ( not c.castAt or now - c.castAt > 0.4 ) then
						c.castAt = now;
					end
				end
				c.left, c.max, c.seen = left, mx, now;
			end
		end
		spellKeys = table.getn(keys) > 0 and table.concat(keys, ", ") or "an empty list";
		-- a spell the line no longer lists is one the hero doesn't have: its telegraph goes
		for key in pairs(cds) do
			if ( not have[key] ) then
				cds[key] = nil;
			end
		end
	end
	if ( playing ) then
		for key, c in pairs(cds) do
			if ( c.left ) then
				local before = c.left;
				c.left = c.left - dt;
				if ( before > 0 and c.left <= 0 ) then
					-- ready: it casts on its own now, so the fill starts over
					c.castAt = now;
					c.left = c.left + c.max;
				elseif ( c.left < 0 ) then
					c.left = 0;
				end
			end
		end
	end
end

---------------------------------------------------------------------------------------------
-- Your shield, off the AZSBUFFS line ({ spell, left })

local shield = { up = false };

local function UpdateShield(now, def)
	local set = def.buffSet;
	if ( not set ) then
		set = {};
		for i = 1, table.getn(def.buffSpells) do
			set[def.buffSpells[i]] = true;
		end
		def.buffSet = set;
	end
	local up = false;
	local list = AZS_BUFFS or {};
	for i = 1, table.getn(list) do
		if ( set[tonumber(list[i].spell)] ) then
			up = true;
		end
	end
	if ( shield.up and not up ) then
		shield.brokeAt = now;
	end
	shield.up = up;
end

---------------------------------------------------------------------------------------------
-- What your hero has: its talents and jewelry off the meter's loadout, and the effects whose
-- own damage the combat text has shown this run

local owned = { at = -100, keys = {}, from = {}, caps = {}, radii = {} };
local learned = {};        -- key -> when that effect's own damage was last seen this run

-- Every key a meter source answers to: its name, item, talent and spell, and "item/<spell>"
-- for an amulet that remakes a spell.
local function SourceKeys(s, into)
	into = into or {};
	if ( type(s) ~= "table" ) then
		return into;
	end
	local item = s.itemKey or s.itemInstanceKey or s.itemId;
	if ( s.name ) then
		into[Norm(s.name)] = true;
	end
	if ( s.itemKey ) then
		into[Norm(s.itemKey)] = true;
	end
	if ( s.talentKey ) then
		into[Norm(s.talentKey)] = true;
	end
	local spell = s.variantKey or s.abilityKey;
	if ( spell and item ) then
		into["item/" .. Norm(spell)] = true;
	elseif ( s.abilityKey ) then
		into[Norm(s.abilityKey)] = true;
	end
	return into;
end

-- Equipped items, by what their tooltips say: { text on the name or a line, key it gives }.
-- A legendary amulet is named "<amulet>: <the spell it remakes>".
local GEAR = {
	{ "When Power Word: Shield breaks it explodes", "item/pwshield" },
	{ ": Power Word: Shield$", "item/pwshield" },
	{ "die with Shadow Word: Pain on them explode", "item/swpain" },
	{ "Pendant of the Plague: Shadow Word: Pain", "item/swpain" },
	{ "die with Devouring Plague on them explode", "item/devouringplague" },
	{ "Pendant of the Plague: Devouring Plague", "item/devouringplague" },
	{ "Enemies you kill explode", "chokerofthefirelord" },
	{ "Choker of the Fire Lord", "chokerofthefirelord" },
	{ "critical hits splash", "onyxiatoothpendant" },
	{ "Onyxia Tooth Pendant", "onyxiatoothpendant" },
};

-- Keys a talent gives; every other key is an item's, and items can be swapped mid-run.
local TALENT_KEYS = { shadowform = true, divineaegis = true };

-- What your gear gives: keys, and per key the item and the numbers its own text states (an
-- empowered amulet's grow). Returns how many items it could see.
local function ReadGear(keys, from, caps, radii)
	local seen = 0;
	for slot = 1, 19 do
		local link = GetInventoryItemLink and GetInventoryItemLink("player", slot);
		if ( link ) then
			seen = seen + 1;
			local lines = TipLines("SetInventoryItem", "player", slot) or {};
			local _, _, name = string.find(link, "%[(.-)%]");
			if ( name and lines[1] ~= name ) then
				table.insert(lines, 1, name);
			end
			for i = 1, table.getn(lines) do
				local line = lines[i];
				for r = 1, table.getn(GEAR) do
					if ( string.find(line, GEAR[r][1]) ) then
						local key = GEAR[r][2];
						keys[key] = true;
						from[key] = from[key] or (lines[1] or "an item");
						local _, _, cap = string.find(line, "at most (%d+) times? a second");
						local _, _, radius = string.find(line, "within ([%d%.]+) y");
						if ( cap ) then
							caps[key] = tonumber(cap);
						end
						if ( radius ) then
							radii[key] = tonumber(radius);
						end
					end
				end
			end
		end
	end
	return seen;
end

-- What your talents give, through the client's talent list, and Shadowform's aura (its
-- capstone keeps you in it all run).
local function ReadTalents(keys, from)
	if ( GetNumTalentTabs and GetNumTalents and GetTalentInfo ) then
		for tab = 1, (GetNumTalentTabs() or 0) do
			for i = 1, (GetNumTalents(tab) or 0) do
				local name, _, _, _, rank = GetTalentInfo(tab, i);
				if ( name and (tonumber(rank) or 0) > 0 ) then
					keys[Norm(name)] = true;
					from[Norm(name)] = from[Norm(name)] or "talent";
				end
			end
		end
	end
	for i = 1, 40 do
		local texture = UnitBuff and UnitBuff("player", i);
		if ( not texture ) then
			break;
		end
		if ( string.find(texture, "Shadowform") ) then
			keys.shadowform = true;
			from.shadowform = from.shadowform or "Shadowform aura";
		end
	end
	local buffs = AZS_BUFFS or {};
	for i = 1, table.getn(buffs) do
		local spell = tonumber(buffs[i].spell);
		if ( spell == 15473 or spell == 16592 ) then
			keys.shadowform = true;
			from.shadowform = from.shadowform or "Shadowform aura";
		end
	end
end

local function RefreshOwned(now)
	if ( now - owned.at < 2 ) then
		return;
	end
	owned.at = now;
	local keys, from, caps, radii = {}, {}, {}, {};
	owned.gearSeen = ReadGear(keys, from, caps, radii) > 0;
	ReadTalents(keys, from);
	owned.from, owned.caps, owned.radii = from, caps, radii;
	if ( type(AZS_GetMeterLoadout) == "function" and type(AZS_GetMeterContext) == "function" ) then
		local ctx = AZS_GetMeterContext();
		local l, err = nil, nil;
		if ( type(ctx) == "table" and ctx.runId ) then
			l, err = AZS_GetMeterLoadout({ apiVersion = 1, runId = ctx.runId });
		end
		if ( type(l) == "table" ) then
			local src = type(l.sources) == "table" and l.sources or {};
			for _, t in ipairs(l.talents or {}) do
				if ( (tonumber(t.rank) or 0) > 0 ) then
					SourceKeys(src[t.sourceKey], keys);
				end
			end
			for _, j in ipairs(l.runJewelry or {}) do
				SourceKeys(src[j.sourceKey], keys);
			end
			for _, e in ipairs(l.equipment or {}) do
				if ( e.occupied ) then
					SourceKeys(src[e.sourceKey], keys);
				end
			end
			owned.status = "read";
		else
			owned.status = ErrText(err or "no run");
		end
	end
	owned.keys = keys;
end

-- The key that gives `def` to your hero and how that is known (the item, "talent", "loadout"
-- or "seen"), or nil. An effect seen going off proves a talent for the whole run; an item only
-- while the gear can't be read, and only for 15 seconds after it last went off, as amulets get
-- swapped mid-run.
local function Has(def, now)
	if ( not def.match ) then
		return true;
	end
	for i = 1, table.getn(def.match) do
		if ( owned.keys[def.match[i]] ) then
			return def.match[i], owned.from[def.match[i]] or "loadout";
		end
	end
	for i = 1, table.getn(def.match) do
		local k = def.match[i];
		local at = learned[k];
		if ( at and ( TALENT_KEYS[k] or ( not owned.gearSeen and now - at < 15 ) ) ) then
			return k, "seen";
		end
	end
	return nil;
end

---------------------------------------------------------------------------------------------
-- Effects around enemies, off the combat text feed: every hit you land, with its target, its
-- spell, whether it crit, its meter source and an anchor where it landed. A kill is a hit whose
-- target is dead (targetState) when its anchor is projected.

local rings = {};          -- { kind = def id, x, y (world), at }
local ctCursor, ctPrimed, ctNext = nil, false, 0;
local ctStatus = "not read yet";
local fired = {};          -- def id -> how many times it went off
local lastFire = {};       -- def id -> when, for the "at most N times a second" caps
local killed = {};         -- target id -> when, so one death counts once
local dots = { swp = {}, dp = {} };   -- target id -> the last tick of your DoT on it
local lastEvent, lastProjection;

local function Truthy(v)
	return v == true or v == 1 or v == "1" or v == "true";
end

-- The meter's descriptor of a hit's source.
local function SourceOf(ev)
	local st = AZS_ML and AZS_ML.st;
	if ( type(ev) == "table" and ev.meterSourceKey and type(st) == "table" and type(st.sources) == "table" ) then
		return st.sources[ev.meterSourceKey];
	end
end

-- Which of your damage-over-time effects a tick is: "swp", "dp" or nil.
local function DotOf(ev, keys)
	local spell, name = tonumber(ev.spellId), Norm(ev.abilityName);
	if ( spell == 589 or name == "shadowwordpain" or keys.swpain ) then
		return "swp";
	elseif ( spell == 2944 or name == "devouringplague" or keys.devouringplague ) then
		return "dp";
	end
end

-- How long after its last tick a DoT surely still sits on an enemy: a tick every second at
-- base, faster with DoT haste.
local function DotWindow()
	local haste = (AZS_STATS and tonumber(AZS_STATS.doth)) or 0;
	return 1.3 / (1 + math.max(0, haste)) + 0.25;
end

local function Fire(def, x, y, now, cap)
	if ( cap and lastFire[def.id] and now - lastFire[def.id] < 1 / cap ) then
		return;
	end
	lastFire[def.id] = now;
	fired[def.id] = (fired[def.id] or 0) + 1;
	table.insert(rings, { kind = def.id, x = x, y = y, at = now });
end

-- active: the enemy effects your hero has, { def, has } each. onShield: a shield burst's own
-- damage was seen.
local function PollEvents(now, p, active, onShield)
	if ( now < ctNext or type(AZS_GetCombatTextEvents) ~= "function" ) then
		return;
	end
	ctNext = now + 0.1;
	local res, err = AZS_GetCombatTextEvents(ctCursor, 256);
	if ( not res ) then
		ctStatus = "feed: " .. ErrText(err);
		if ( type(err) == "table" and ( err.code == "STREAM_CHANGED" or err.code == "INVALID_ARGUMENT" ) ) then
			ctCursor, ctPrimed = nil, false;
		end
		return;
	end
	ctCursor = res.nextCursor or res.cursor or ctCursor;
	local events = Entries(res, "events") or {};
	if ( not ctPrimed ) then
		-- the feed keeps 5 seconds: those happened before we looked
		ctPrimed = true;
		ctStatus = "listening";
		return;
	end
	local wantKills, wantCrits = false, false;
	for i = 1, table.getn(active) do
		if ( active[i].def.trigger == "kill" ) then
			wantKills = true;
		else
			wantCrits = true;
		end
	end
	local ids, evs = {}, {};
	for i = 1, table.getn(events) do
		local ev = events[i];
		if ( type(ev) == "table" and ev.kind ~= "miss" ) then
			lastEvent = ev;
			local keys = SourceKeys(SourceOf(ev));
			-- an effect's own damage: your hero has it, and it just went off
			for j = 1, table.getn(DEFS) do
				local def = DEFS[j];
				if ( def.match ) then
					for k = 1, table.getn(def.match) do
						if ( keys[def.match[k]] ) then
							learned[def.match[k]] = now;
							ev.effect = def.id;
						end
					end
				end
			end
			if ( ev.effect == "shield" ) then
				onShield(now);
			end
			local t = ev.targetId or ev.targetUnitId;
			if ( t and Truthy(ev.periodic) ) then
				local dot = DotOf(ev, keys);
				if ( dot ) then
					dots[dot][t] = now;
				end
			end
			if ( ev.anchorId and ev.anchorStatus ~= "unavailable" and table.getn(ids) < 256
				and ( wantKills or ( wantCrits and Truthy(ev.critical) ) ) ) then
				table.insert(ids, tostring(ev.anchorId));
				table.insert(evs, ev);
			end
		end
	end
	if ( table.getn(ids) > 0 ) then
		local pres, perr = AZS_ProjectCombatTextAnchors(ids, "impact");
		local list = Entries(pres);
		if ( not list ) then
			ctStatus = "projection: " .. ErrText(perr);
			return;
		end
		local window = DotWindow();
		for i = 1, table.getn(ids) do
			local ev, e = evs[i], list[i];
			if ( type(e) == "table" and type(e.x) == "number" and type(e.y) == "number" ) then
				lastProjection = e;
				local u, v = Unmap(e.x, e.y);
				if ( u ) then
					local x, y = p.x + u, p.y + v;
					local t = ev.targetId or ev.targetUnitId or ev.anchorId;
					-- a combat text anchor's target: "alive", "dead" or "unavailable"
					if ( e.targetState == "dead" and not killed[t] ) then
						-- a kill: each kill effect your hero has, if the enemy died the way it needs
						killed[t] = now;
						local swp = dots.swp[t] and now - dots.swp[t] < window;
						local dp = dots.dp[t] and now - dots.dp[t] < window;
						for j = 1, table.getn(active) do
							local a = active[j];
							if ( a.def.trigger == "kill" ) then
								local need = a.def.needs and a.def.needs[a.has];
								if ( not need or ( need == "swp" and swp ) or ( need == "dp" and dp )
									or ( need == "any" and ( swp or dp ) ) ) then
									Fire(a.def, x, y, now, owned.caps[a.has] or a.def.cap);
								end
							end
						end
					end
					if ( Truthy(ev.critical) and ev.effect ~= "onyxia" ) then
						-- a crit, not the splash's own
						for j = 1, table.getn(active) do
							local a = active[j];
							if ( a.def.trigger == "crit" ) then
								Fire(a.def, x, y, now, owned.caps[a.has] or a.def.cap);
							end
						end
					end
				end
			end
		end
	end
	ctStatus = "listening";
	for t, at in pairs(killed) do
		if ( now - at > 3 ) then
			killed[t] = nil;
		end
	end
	for _, list in pairs(dots) do
		for t, at in pairs(list) do
			if ( now - at > 10 ) then
				list[t] = nil;
			end
		end
	end
end

---------------------------------------------------------------------------------------------
-- Each frame

-- (Lua 5.0 lets one function reach at most 32 of the file's locals, so a frame's work is split
-- into the pieces below.)

local lastNow, effectsRun;
local preview = {};    -- by id: the time a Test press ends
local info = {};       -- by id: what the options window shows
local drawCalls, drawnQuads = 0, 0;

-- A new run: what was learned about the last one goes.
local function CheckRun()
	local run = AZS_ZONE and AZS_ZONE.run;
	if ( run ~= effectsRun ) then
		effectsRun = run;
		learned, rings, killed, lastFire = {}, {}, {}, {};
		dots = { swp = {}, dp = {} };
		owned.at = -100;
	end
end

-- A shield burst's own damage came through: the shield broke now.
local function OnShieldBurst(now)
	if ( not shield.brokeAt or now - shield.brokeAt > 0.5 ) then
		shield.brokeAt = now;
	end
	shield.up = false;
end

-- An enemy effect's rings where it went off, growing to their size as they fade; a Test press
-- shows three near the hero, one after another.
local function DrawRings(j, p, now)
	local st = j.st;
	if ( j.test ) then
		for k = 0, 2 do
			local age = j.test - k * 0.8;
			if ( age >= 0 and age < st.flash ) then
				local a = k * 2.1;
				DrawCircleAt(8 * math.cos(a), 8 * math.sin(a), j.size * (0.6 + 0.4 * age / st.flash), st,
					j.alpha * (1 - age / st.flash), nil, nil, 0, 1);
			end
		end
	end
	-- the newest first; with a cap set (st.most > 0), only that many
	local drawn = 0;
	for k = table.getn(rings), 1, -1 do
		local r = rings[k];
		local age = now - r.at;
		if ( age > 2 ) then
			table.remove(rings, k);
		elseif ( r.kind == j.def.id and age < st.flash and ( st.most <= 0 or drawn < st.most ) ) then
			drawn = drawn + 1;
			DrawCircleAt(r.x - p.x, r.y - p.y, j.size * (0.6 + 0.4 * age / st.flash), st,
				1 - age / st.flash, nil, nil, 0, 1);
		end
	end
end

-- What to draw this frame: the jobs, the enemy effects your hero has, and whether the combat
-- text needs reading.
local function CollectJobs(now, inRun)
	local jobs, active, watch = {}, {}, false;
	for i = 1, table.getn(DEFS) do
		local def = DEFS[i];
		local st = Settings(def);
		local test = preview[def.id] and now < preview[def.id];
		local inf = info[def.id];
		if ( not inf ) then
			inf = {};
			info[def.id] = inf;
		end
		if ( st.enabled or test ) then
			local job = { def = def, st = st, alpha = 1 };
			local has, how;
			if ( def.match ) then
				-- an effect: the feed tells whether your hero has it, so it is read either way
				watch = true;
				RefreshOwned(now);
				has, how = Has(def, now);
				inf.has, inf.how = has, how;
			end
			if ( def.sizePattern and now - (inf.read or 0) > 1 ) then
				ReadSize(def, now);
				inf.read = now;
			end
			job.size, inf.source = SizeOf(def, st, now, has, has and owned.radii[has]);
			inf.size = job.size;
			local c = SpellOf(def);
			inf.known = c ~= nil;
			inf.left, inf.max = c and c.left, c and c.max;
			if ( c and c.castAt ) then
				job.since = now - c.castAt;
			end
			if ( test ) then
				-- a Test press: three seconds, as the chosen mode would look
				local t = 3 - (preview[def.id] - now);
				job.show = true;
				job.alpha = math.min(1, (preview[def.id] - now) / 0.5);
				if ( st.mode == "cooldown" ) then
					-- two cooldowns of 1.5 seconds
					local cycle = t - math.floor(t / 1.5) * 1.5;
					job.progress = cycle / 1.5;
					job.since = cycle;
				elseif ( def.shape == "enemy" ) then
					job.test = t;
				else
					job.since = t;
				end
			elseif ( st.mode == "cast" ) then
				if ( job.since and job.since < st.flash ) then
					job.alpha = 1 - job.since / st.flash;
					job.show = inRun;
				end
			elseif ( st.mode == "cooldown" ) then
				if ( c and c.max ) then
					job.progress = 1 - c.left / c.max;
					if ( job.since and job.since < 0.25 ) then
						job.progress = 0;
					end
					job.show = inRun;
				end
			elseif ( st.mode == "shield" ) then
				UpdateShield(now, def);
				inf.shieldUp = shield.up;
				if ( not has ) then
					-- no burst comes of your shield without Divine Aegis or the amulet
				elseif ( shield.up ) then
					job.show = inRun;
					job.alpha = 0.75 + 0.25 * math.sin(now * 4);
				elseif ( shield.brokeAt and now - shield.brokeAt < st.flash ) then
					job.show = inRun;
					job.since = now - shield.brokeAt;
					job.alpha = 1 - job.since / st.flash;
				end
			elseif ( st.mode == "event" ) then
				if ( has ) then
					table.insert(active, { def = def, has = has });
					job.show = inRun;
				end
			else
				job.show = true;
			end
			if ( job.show ) then
				table.insert(jobs, job);
			end
		end
	end
	return jobs, active, watch;
end

local function RenderJobs(now, jobs, active, watch, inRun)
	local p, err = AZS_GetPlayerPosition();
	if ( not p ) then
		lastError = "player position: " .. ErrText(err);
		return;
	end
	if ( not BuildMap(p) ) then
		return;
	end
	if ( watch and inRun ) then
		PollEvents(now, p, active, OnShieldBurst);
	end
	local up, turn;
	local facing = p.facing or 0;
	if ( db.mirror ) then
		facing = -facing;
	end
	facing = facing + (db.rotate or 0) * PI / 180;
	for i = 1, table.getn(jobs) do
		local j = jobs[i];
		if ( j.def.shape == "cone" ) then
			j.facing = facing;
			DrawCone(j);
		elseif ( j.def.shape == "circle" ) then
			if ( j.progress and not up ) then
				-- the cooldown sweeps clockwise from the top of the screen
				up, turn = ScreenUp();
			end
			DrawCircleAt(0, 0, j.size, j.st, j.alpha, j.progress, j.since, up or 0, turn or 1);
		else
			DrawRings(j, p, now);
		end
	end
end

local function Draw()
	drawCalls = drawCalls + 1;
	local now = GetTime();
	local dt = now - (lastNow or now);
	lastNow = now;
	if ( dt > 0.5 ) then
		dt = 0.5;
	end
	if ( not db ) then
		return;
	end
	local phase = AZS_GetPhase and AZS_GetPhase();
	local inRun = phase ~= nil and phase ~= "dead" and phase ~= "victory";
	UpdateCooldowns(now, dt, phase == "playing");
	CheckRun();
	screenW, screenH = WorldFrame:GetWidth() or screenW, WorldFrame:GetHeight() or screenH;
	local jobs, active, watch = CollectJobs(now, inRun);
	if ( table.getn(jobs) > 0 or ( watch and inRun ) ) then
		RenderJobs(now, jobs, active, watch, inRun);
	end
	drawnQuads = used;
	FinishQuads();
end

local function Start()
	if ( type(AZS_RegisterWorldAnchorFrameHandler) == "function" ) then
		-- runs after this frame's camera, so the telegraphs don't trail the hero by a frame
		AZS_RegisterWorldAnchorFrameHandler(Draw);
	elseif ( type(AZS_ProjectWorldAnchors) == "function" ) then
		canvas:SetScript("OnUpdate", Draw);
	else
		Print("this client has no world-anchor API, so nothing can be drawn.");
	end
end

---------------------------------------------------------------------------------------------
-- Options window

local BACKDROP = {
	bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true, tileSize = 16, edgeSize = 16,
	insets = { left = 4, right = 4, top = 4, bottom = 4 },
};
local FLAT = {
	bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true, tileSize = 8, edgeSize = 10,
	insets = { left = 2, right = 2, top = 2, bottom = 2 },
};
local PRESETS = {
	{ 1, 0.25, 0.25 }, { 1, 0.6, 0.15 }, { 1, 0.95, 0.3 }, { 0.35, 1, 0.35 },
	{ 0.3, 0.9, 1 }, { 0.35, 0.5, 1 }, { 0.75, 0.45, 1 }, { 1, 1, 1 },
};

local options;
local selected = DEFS[1];
local refreshers = {};
local CX = 130;        -- where a row's controls start, right of its label

local function Refresh()
	for i = 1, table.getn(refreshers) do
		refreshers[i]();
	end
end

local function Label(parent, text, font)
	local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall");
	fs:SetText(text);
	return fs;
end

local function Button(parent, text, w, h, onClick)
	local b = CreateFrame("Button", nil, parent);
	b:SetWidth(w);
	b:SetHeight(h);
	b:SetBackdrop(FLAT);
	b:SetBackdropColor(0.12, 0.12, 0.16, 0.95);
	b:SetBackdropBorderColor(0.45, 0.45, 0.55, 1);
	b.text = Label(b, text);
	b.text:SetPoint("CENTER", b, "CENTER", 0, 0);
	b:SetScript("OnClick", onClick);
	b:SetScript("OnEnter", function() b:SetBackdropBorderColor(1, 0.82, 0, 1); end);
	b:SetScript("OnLeave", function()
		if ( b.active ) then
			b:SetBackdropBorderColor(0.75, 0.55, 1, 1);
		else
			b:SetBackdropBorderColor(0.45, 0.45, 0.55, 1);
		end
	end);
	return b;
end

local function SetActive(b, on)
	b.active = on;
	if ( on ) then
		b:SetBackdropColor(0.3, 0.18, 0.45, 0.95);
		b:SetBackdropBorderColor(0.75, 0.55, 1, 1);
	else
		b:SetBackdropColor(0.12, 0.12, 0.16, 0.95);
		b:SetBackdropBorderColor(0.45, 0.45, 0.55, 1);
	end
end

-- A row: its label on the left, the caller fills the rest. `when(def)` says whether it shows.
local rows = {};
local function Row(panel, label, when)
	local row = CreateFrame("Frame", nil, panel);
	row:SetWidth(390);
	row:SetHeight(22);
	row.label = Label(row, label, "GameFontNormalSmall");
	row.label:SetPoint("LEFT", row, "LEFT", 0, 0);
	row.when = when;
	table.insert(rows, row);
	return row;
end

local function Layout(panel)
	local y = -8;
	for i = 1, table.getn(rows) do
		local row = rows[i];
		if ( not row.when or row.when(selected) ) then
			row:ClearAllPoints();
			row:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, y);
			row:Show();
			y = y - 23;
		else
			row:Hide();
		end
	end
end

local function Check(panel, label, when, get, set)
	local row = Row(panel, label, when);
	local b = Button(row, "", 18, 18, function()
		set(not get());
		Refresh();
	end);
	b:SetPoint("LEFT", row, "LEFT", CX, 0);
	local mark = b:CreateTexture(nil, "OVERLAY");
	mark:SetTexture(SOLID);
	mark:SetVertexColor(0.75, 0.55, 1, 1);
	mark:SetWidth(10);
	mark:SetHeight(10);
	mark:SetPoint("CENTER", b, "CENTER", 0, 0);
	table.insert(refreshers, function()
		if ( get() ) then
			mark:Show();
		else
			mark:Hide();
		end
	end);
	return row;
end

-- choices: { value, label, width } each, or a function of the selected telegraph giving them.
local function Choice(panel, label, when, choices, get, set)
	local row = Row(panel, label, when);
	local buttons = {};
	for i = 1, 3 do
		local b = Button(row, "", 60, 18, function()
			set(buttons[i].value);
			Refresh();
		end);
		buttons[i] = b;
	end
	table.insert(refreshers, function()
		local list = choices;
		if ( type(list) == "function" ) then
			list = list(selected) or {};
		end
		local x = CX;
		for i = 1, 3 do
			local b, ch = buttons[i], list[i];
			if ( ch ) then
				b.value = ch[1];
				b.text:SetText(ch[2]);
				b:SetWidth(ch[3]);
				b:ClearAllPoints();
				b:SetPoint("LEFT", row, "LEFT", x, 0);
				x = x + ch[3] + 4;
				SetActive(b, get() == ch[1]);
				b:Show();
			else
				b:Hide();
			end
		end
	end);
	return row;
end

-- A number with - and + (shift: five steps), the mouse wheel over the row too.
local function Stepper(panel, label, when, get, set, step, lo, hi, fmt)
	local row = Row(panel, label, when);
	local value = Label(row, "");
	local function Nudge(n)
		if ( IsShiftKeyDown and IsShiftKeyDown() ) then
			n = n * 5;
		end
		local v = math.floor((get() + n * step) / step + 0.5) * step;
		if ( v < lo ) then
			v = lo;
		elseif ( v > hi ) then
			v = hi;
		end
		set(v);
		Refresh();
	end
	local minus = Button(row, "-", 20, 18, function() Nudge(-1); end);
	minus:SetPoint("LEFT", row, "LEFT", CX, 0);
	value:SetPoint("LEFT", row, "LEFT", CX + 26, 0);
	value:SetWidth(100);
	local plus = Button(row, "+", 20, 18, function() Nudge(1); end);
	plus:SetPoint("LEFT", row, "LEFT", CX + 130, 0);
	row:EnableMouseWheel(true);
	row:SetScript("OnMouseWheel", function()
		if ( arg1 and arg1 > 0 ) then
			Nudge(1);
		else
			Nudge(-1);
		end
	end);
	table.insert(refreshers, function()
		value:SetText(fmt(get()));
	end);
	return row;
end

-- A colour: its swatch, the presets, and the colour picker if the client has one.
local function Color(panel, label, when, key)
	local row = Row(panel, label, when);
	local swatch = row:CreateTexture(nil, "OVERLAY");
	swatch:SetTexture(SOLID);
	swatch:SetWidth(18);
	swatch:SetHeight(18);
	swatch:SetPoint("LEFT", row, "LEFT", CX, 0);
	local function SetRGB(r, g, b)
		local c = Settings(selected)[key];
		c[1], c[2], c[3] = r, g, b;
		Refresh();
	end
	local x = CX + 24;
	for i = 1, table.getn(PRESETS) do
		local pc = PRESETS[i];
		local b = CreateFrame("Button", nil, row);
		b:SetWidth(14);
		b:SetHeight(14);
		b:SetPoint("LEFT", row, "LEFT", x, 0);
		local t = b:CreateTexture(nil, "OVERLAY");
		t:SetTexture(SOLID);
		t:SetVertexColor(pc[1], pc[2], pc[3], 1);
		t:SetAllPoints(b);
		b:SetScript("OnClick", function() SetRGB(pc[1], pc[2], pc[3]); end);
		x = x + 17;
	end
	if ( ColorPickerFrame ) then
		local pick = Button(row, "Pick", 40, 18, function()
			local c = Settings(selected)[key];
			local before = { r = c[1], g = c[2], b = c[3] };
			ColorPickerFrame.hasOpacity = nil;
			ColorPickerFrame.previousValues = before;
			ColorPickerFrame.func = function()
				SetRGB(ColorPickerFrame:GetColorRGB());
			end;
			ColorPickerFrame.cancelFunc = function()
				SetRGB(before.r, before.g, before.b);
			end;
			ColorPickerFrame:SetColorRGB(c[1], c[2], c[3]);
			if ( ShowUIPanel ) then
				ShowUIPanel(ColorPickerFrame);
			else
				ColorPickerFrame:Show();
			end
		end);
		pick:SetPoint("LEFT", row, "LEFT", x + 4, 0);
	end
	table.insert(refreshers, function()
		local c = Settings(selected)[key];
		swatch:SetVertexColor(c[1], c[2], c[3], 1);
	end);
	return row;
end

local function Pct(v) return string.format("%d%%", math.floor(v * 100 + 0.5)); end
local function Px(v) return string.format("%g px", v); end
local function Yd(v) return string.format("%g yd", v); end

-- The status rows' texts for the selected telegraph: its size, where it comes from, and how
-- the drawing goes. `elapsed`: seconds since the last call.
local statusCalls = 0;
local function StatusTexts(elapsed)
	local rate = (drawCalls - statusCalls) / elapsed;
	statusCalls = drawCalls;
	local i = info[selected.id] or {};
	local size, source, drawing = "not measured yet", "", "";
	if ( i.size and selected.shape == "cone" ) then
		size = string.format("%.1f yd long, %d deg wide (%s)", i.size, 2 * selected.halfAngle, i.source);
	elseif ( i.size ) then
		size = string.format("%.1f yd radius (%s)", i.size, tostring(i.source));
	end
	if ( selected.spellKey ) then
		if ( i.known ) then
			source = string.format("found: cooldown %.1f of %.1f sec", i.left or 0, i.max or 0);
		else
			local keys = spellKeys;
			if ( string.len(keys) > 40 ) then
				keys = string.sub(keys, 1, 40) .. "...";
			end
			source = "not in your spells (" .. keys .. ")";
		end
	elseif ( selected.match ) then
		if ( i.has ) then
			if ( i.how == "seen" ) then
				source = "seen going off this run";
			else
				source = "you have it (" .. tostring(i.how) .. ")";
			end
			if ( selected.buffSpells ) then
				source = source .. (shield.up and ", shield up" or ", no shield now");
			else
				source = source .. string.format(", went off %d times", fired[selected.id] or 0);
			end
		else
			source = "not on your hero: needs " .. (selected.needName or selected.name);
		end
	end
	if ( lastError ) then
		drawing = lastError;
	else
		drawing = string.format("%d quads, %.0f updates/sec", drawnQuads, rate);
	end
	return size, source, drawing;
end

local function BuildOptions()
	options = CreateFrame("Frame", "PriestTelegraphsOptions", UIParent);
	options:SetWidth(580);
	options:SetHeight(520);
	options:SetFrameStrata("DIALOG");
	options:SetBackdrop(BACKDROP);
	options:SetBackdropBorderColor(0.6, 0.6, 0.7, 1);
	options:EnableMouse(true);
	options:SetMovable(true);
	options:RegisterForDrag("LeftButton");
	options:SetScript("OnDragStart", function() options:StartMoving(); end);
	options:SetScript("OnDragStop", function()
		options:StopMovingOrSizing();
		local point, _, rel, x, y = options:GetPoint();
		db.pos = { point = point, rel = rel, x = x, y = y };
	end);
	if ( db.pos and db.pos.point ) then
		options:SetPoint(db.pos.point, UIParent, db.pos.rel or db.pos.point, db.pos.x, db.pos.y);
	else
		options:SetPoint("CENTER", UIParent, "CENTER", 0, 40);
	end
	if ( UISpecialFrames ) then
		table.insert(UISpecialFrames, "PriestTelegraphsOptions");
	end

	local title = Label(options, "Priest Telegraphs", "GameFontNormal");
	title:SetPoint("TOP", options, "TOP", 0, -12);
	local close = Button(options, "x", 20, 20, function() options:Hide(); end);
	close:SetPoint("TOPRIGHT", options, "TOPRIGHT", -8, -8);

	-- the list of telegraphs
	local list = CreateFrame("Frame", nil, options);
	list:SetWidth(140);
	list:SetPoint("TOPLEFT", options, "TOPLEFT", 12, -36);
	list:SetPoint("BOTTOMLEFT", options, "BOTTOMLEFT", 12, 12);
	list:SetBackdrop(FLAT);
	list:SetBackdropColor(0, 0, 0, 0.5);
	local panel = CreateFrame("Frame", nil, options);
	panel:SetPoint("TOPLEFT", list, "TOPRIGHT", 8, 0);
	panel:SetPoint("BOTTOMRIGHT", options, "BOTTOMRIGHT", -12, 12);
	panel:SetBackdrop(FLAT);
	panel:SetBackdropColor(0, 0, 0, 0.5);

	local entries = {};
	for i = 1, table.getn(DEFS) do
		local def = DEFS[i];
		local b = Button(list, def.name, 124, 22, function()
			selected = def;
			Layout(panel);
			Refresh();
		end);
		b:SetPoint("TOPLEFT", list, "TOPLEFT", 8, -8 - 25 * (i - 1));
		entries[i] = { b, def };
	end
	table.insert(refreshers, function()
		for i = 1, table.getn(entries) do
			SetActive(entries[i][1], entries[i][2] == selected);
			if ( Settings(entries[i][2]).enabled ) then
				entries[i][1].text:SetTextColor(1, 1, 1);
			else
				entries[i][1].text:SetTextColor(0.5, 0.5, 0.5);
			end
		end
	end);

	local function S() return Settings(selected); end
	local function Smooth(d) return S().style ~= "dots"; end
	local function Dotty(d) return S().style == "dots"; end
	local function Filling(d) return S().mode == "cooldown"; end

	Check(panel, "Shown", nil, function() return S().enabled; end, function(v) S().enabled = v; end);
	Choice(panel, "Style", nil, { { "smooth", "Smooth", 80 }, { "dots", "Dots", 60 } },
		function() return S().style; end, function(v) S().style = v; end);
	Choice(panel, "When", function(d) return d.modes ~= nil; end, function(d) return d.modes; end,
		function() return S().mode; end, function(v) S().mode = v; end);
	Stepper(panel, "Flash length", function(d) return S().mode == "cast" or S().mode == "event" or S().mode == "shield"; end,
		function() return S().flash; end, function(v) S().flash = v; end, 0.1, 0.1, 5,
		function(v) return string.format("%.1f sec", v); end);
	local function Sized(d) return d.sizePattern ~= nil or d.radius ~= nil or d.radii ~= nil; end
	Stepper(panel, "Size override", Sized,
		function() return S().length; end, function(v) S().length = v; end, 0.5, 0, 100,
		function(v)
			if ( v <= 0 ) then
				return "off (automatic)";
			end
			return Yd(v);
		end);
	-- fewer rings when a pack dies at once, for slower computers
	Stepper(panel, "Most at once", function(d) return d.shape == "enemy"; end,
		function() return S().most; end, function(v) S().most = v; end, 1, 0, 40,
		function(v)
			if ( v <= 0 ) then
				return "off (all rings)";
			end
			return string.format("%d rings", v);
		end);
	Stepper(panel, "Radius", function(d) return not Sized(d); end,
		function() return S().radius; end, function(v) S().radius = v; end, 0.5, 0.5, 100, Yd);
	Color(panel, "Outline colour", nil, "line");
	Stepper(panel, "Outline opacity", nil, function() return S().line[4]; end, function(v) S().line[4] = v; end,
		0.05, 0, 1, Pct);
	Color(panel, "Fill colour", nil, "fill");
	Stepper(panel, "Fill opacity", nil, function() return S().fill[4]; end, function(v) S().fill[4] = v; end,
		0.05, 0, 1, Pct);
	Stepper(panel, "Outline width", Smooth, function() return S().width; end, function(v) S().width = v; end,
		1, 1, 12, Px);
	Check(panel, "Glow", Smooth, function() return S().glow; end, function(v) S().glow = v; end);
	Stepper(panel, "Fill detail", Smooth, function() return S().strip; end, function(v) S().strip = v; end,
		1, 1, 8, function(v) return string.format("%g px strips", v); end);
	Stepper(panel, "Dot size", Dotty, function() return S().size; end, function(v) S().size = v; end,
		1, 1, 16, Px);
	Stepper(panel, "Dot spacing", Dotty, function() return S().spacing; end, function(v) S().spacing = v; end,
		1, 3, 40, Px);
	Choice(panel, "Fill style", function(d) return Dotty(d) and Filling(d); end,
		{ { "solid", "Solid", 70 }, { "front", "Front line only", 110 } },
		function() return S().fillStyle; end, function(v) S().fillStyle = v; end);
	Stepper(panel, "Fill spacing", function(d) return Dotty(d) and Filling(d) and S().fillStyle == "solid"; end,
		function() return S().fillSpacing; end, function(v) S().fillSpacing = v; end, 1, 4, 60, Px);

	local function Status(label, when)
		local row = Row(panel, label, when);
		local text = Label(row, "");
		text:SetPoint("LEFT", row, "LEFT", CX, 0);
		text:SetWidth(260);
		text:SetJustifyH("LEFT");
		return text;
	end
	local sizeText = Status("Size now", Sized);
	local spellText = Status("Source", function(d) return d.spellKey ~= nil or d.match ~= nil; end);
	local drawText = Status("Drawing");

	-- Test hides this window while it plays, as the window sits over your hero.
	local reopenAt;
	local reopener = CreateFrame("Frame");
	reopener:SetScript("OnUpdate", function()
		if ( reopenAt and GetTime() >= reopenAt ) then
			reopenAt = nil;
			options:Show();
		end
	end);
	local buttons = Row(panel, "");
	local test = Button(buttons, "Test", 70, 20, function()
		preview[selected.id] = GetTime() + 3;
		reopenAt = GetTime() + 3.2;
		options:Hide();
	end);
	test:SetPoint("LEFT", buttons, "LEFT", CX, 0);
	local reset = Button(buttons, "Reset this one", 110, 20, function()
		ResetSettings(selected);
		Refresh();
	end);
	reset:SetPoint("LEFT", test, "RIGHT", 6, 0);

	-- the mode and style change which rows show
	table.insert(refreshers, function() Layout(panel); end);

	local acc = 0;
	options:SetScript("OnUpdate", function()
		acc = acc + (arg1 or 0);
		if ( acc < 0.25 ) then
			return;
		end
		local size, source, drawing = StatusTexts(acc);
		acc = 0;
		sizeText:SetText(size);
		spellText:SetText(source);
		drawText:SetText(drawing);
	end);

	Layout(panel);
	Refresh();
end

local function ToggleOptions()
	if ( not options ) then
		BuildOptions();
		options:Show();
	elseif ( options:IsShown() ) then
		options:Hide();
	else
		Refresh();
		options:Show();
	end
end

---------------------------------------------------------------------------------------------
-- Slash commands, saved settings

local function Dump(t)
	if ( type(t) ~= "table" ) then
		return tostring(t);
	end
	local out = {};
	for k, v in pairs(t) do
		table.insert(out, tostring(k) .. "=" .. tostring(v));
	end
	return table.concat(out, ", ");
end

SLASH_TELEGRAPHS1 = "/tele";
SLASH_TELEGRAPHS2 = "/telegraphs";
SlashCmdList["TELEGRAPHS"] = function(msg)
	local _, _, cmd, rest = string.find(msg or "", "^%s*(%S*)%s*(.-)%s*$");
	cmd = string.lower(cmd or "");
	-- If a cone points the wrong way in game: mirror flips it, rotate turns it by degrees.
	if ( cmd == "mirror" ) then
		db.mirror = not db.mirror;
		Print("cone facing " .. (db.mirror and "mirrored." or "normal."));
		return;
	elseif ( cmd == "rotate" ) then
		db.rotate = tonumber(rest) or 0;
		Print(string.format("cone facing turned by %g degrees.", db.rotate));
		return;
	elseif ( cmd == "events" ) then
		-- what the combat text feed gave last, and what the effects know
		Print("last hit: " .. Dump(lastEvent));
		Print("its source: " .. Dump(SourceOf(lastEvent)));
		Print("its projection: " .. Dump(lastProjection));
		local keys = {};
		for k in pairs(owned.keys) do
			table.insert(keys, k);
		end
		Print("loadout (" .. tostring(owned.status) .. "): " .. table.concat(keys, ", "));
		keys = {};
		for k in pairs(learned) do
			table.insert(keys, k);
		end
		Print("seen going off: " .. table.concat(keys, ", ") .. "; feed " .. ctStatus);
		return;
	elseif ( cmd == "debug" ) then
		local now = GetTime();
		Print("anchor: " .. (anchor and (tostring(anchor.kind) .. " " .. tostring(anchor.anchorId)) or "none")
			.. string.format(", %.1f screen units per yard", scale) .. ", last problem: " .. tostring(lastError or "none"));
		Print("phase " .. tostring(AZS_GetPhase and AZS_GetPhase()) .. ", run " .. tostring(AZS_ZONE and AZS_ZONE.run)
			.. ", area " .. tostring(AZS_STATS and AZS_STATS.area) .. ", spells line: " .. spellKeys);
		for i = 1, table.getn(DEFS) do
			local def = DEFS[i];
			local c = SpellOf(def);
			local t = tipSize[def.id];
			local inf = info[def.id];
			Print(def.name .. ": " .. (Settings(def).enabled and "on" or "off")
				.. (inf and inf.size and string.format(", size %.1f yd from the %s", inf.size, tostring(inf.source)) or "")
				.. (t and t.slot and (", tooltip in action slot " .. t.slot) or "")
				.. (c and string.format(", cooldown %.2f of %.2f sec, last cast %.1f sec ago", c.left or -1, c.max or -1,
					c.castAt and (now - c.castAt) or -1) or ""));
		end
		return;
	end
	ToggleOptions();
end

SLASH_TELEGRAPHSRING1 = "/ring";
SlashCmdList["TELEGRAPHSRING"] = function(msg)
	local st = Settings(byId.ring);
	local v = tonumber(msg);
	if ( v and v > 0 ) then
		st.radius = v;
		st.enabled = true;
	else
		st.enabled = not st.enabled;
	end
	Print("ring " .. (st.enabled and "on" or "off") .. string.format(", %g yd.", st.radius));
	if ( options ) then
		Refresh();
	end
end

local loader = CreateFrame("Frame");
loader:RegisterEvent("ADDON_LOADED");
loader:RegisterEvent("VARIABLES_LOADED");
loader:RegisterEvent("UNIT_INVENTORY_CHANGED");
loader:SetScript("OnEvent", function()
	if ( event == "UNIT_INVENTORY_CHANGED" ) then
		-- an amulet swapped: read the gear again on the next frame
		owned.at = -100;
		return;
	end
	if ( db or ( event == "ADDON_LOADED" and arg1 ~= "PriestTelegraphs" ) ) then
		return;
	end
	if ( type(PriestTelegraphsDB) ~= "table" ) then
		PriestTelegraphsDB = {};
	end
	db = PriestTelegraphsDB;
	db.t = db.t or {};
	for i = 1, table.getn(DEFS) do
		Settings(DEFS[i]);
	end
	Start();
	Print("loaded. /tele for the options.");
end);
