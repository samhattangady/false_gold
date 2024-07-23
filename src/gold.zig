const std = @import("std");
const c = @import("interface.zig");
const haathi_lib = @import("haathi.zig");
const Haathi = @import("haathi.zig").Haathi;
const colors = @import("colors.zig");
const MouseState = @import("inputs.zig").MouseState;
const SCREEN_SIZE = @import("haathi.zig").SCREEN_SIZE;
const CursorStyle = @import("haathi.zig").CursorStyle;

const helpers = @import("helpers.zig");
const Vec2 = helpers.Vec2;
const Vec2i = helpers.Vec2i;
const Vec4 = helpers.Vec4;
const Rect = helpers.Rect;
const Button = helpers.Button;
const TextLine = helpers.TextLine;
const Orientation = helpers.Orientation;
const ConstIndexArray = helpers.ConstIndexArray;
const ConstKey = helpers.ConstKey;
const FONTS = haathi_lib.FONTS;

const PathIndex = ConstKey("gold_path");
const DjinnIndex = ConstKey("gold_djinn");
const StructureIndex = ConstKey("gold_structure");
const ShadowIndex = ConstKey("gold_shadow");
const SpiritIndex = ConstKey("gold_spirit");
const TrapIndex = ConstKey("gold_trap");

const PLAYER_ACCELERATION = 2;
const PLAYER_VELOCITY_MAX = 6;
const PLAYER_VELOCITY_MAX_SQR = PLAYER_VELOCITY_MAX * PLAYER_VELOCITY_MAX;
const PLAYER_VELOCITY_DAMPING = 0.2;
const PLAYER_SIZE = Vec2{ .x = 20, .y = 30 };
const PLAYER_LIGHT_RADIUS = 45;
const PLAYER_LIGHT_RADIUS_SQR = PLAYER_LIGHT_RADIUS * PLAYER_LIGHT_RADIUS;
const PLAYER_LIGHT_SIZE = Vec2{ .x = PLAYER_LIGHT_RADIUS * 2, .y = PLAYER_LIGHT_RADIUS * 2 };
const SPIRIT_LIGHT_RADIUS = 25;
const SPIRIT_LIGHT_RADIUS_SQR = SPIRIT_LIGHT_RADIUS * SPIRIT_LIGHT_RADIUS;
const SPIRIT_LIGHT_SIZE = Vec2{ .x = SPIRIT_LIGHT_RADIUS * 2, .y = SPIRIT_LIGHT_RADIUS * 2 };
const SPIRIT_SIZE = Vec2{ .x = 10, .y = 10 };
const DJINN_SIZE = Vec2{ .x = 16, .y = 22 };
const SHADOW_SIZE = Vec2{ .x = 16, .y = 22 };
const GRID_SIZE = Vec2i{ .x = 32, .y = 18 };
const GRID_CELL_SIZE = Vec2{
    .x = SCREEN_SIZE.x / @as(f32, @floatFromInt(GRID_SIZE.x)),
    .y = SCREEN_SIZE.y / @as(f32, @floatFromInt(GRID_SIZE.y)),
};
const GRID_OFFSET = GRID_SIZE.divide(2);
const SHADOW_VELOCITY_MAX = 1.0;
const SHADOW_VELOCITY_SCARED = 1.8;
const SHADOW_SCARED_TICKS = 120;
const PLAYER_TARGET_RESET_TICKS = 30;
const SHADOW_PICKUP_RADIUS = 15;
const SHADOW_PICKUP_RADIUS_SQR = SHADOW_PICKUP_RADIUS * SHADOW_PICKUP_RADIUS;
const TRAP_SIZE = Vec2{ .x = 30, .y = 30 };
const TRAP_TICKS = 60;
const TRAP_RADIUS = 25;
const TRAP_RADIUS_SQR = TRAP_RADIUS * TRAP_RADIUS;
const TRAP_INDICATOR_SIZE = TRAP_SIZE.x * 1.6;
const ENERGY_DEFAULT_VALUE = 10;

const DJINN_TICK_COUNT = 30;
const build_options = @import("build_options");
const BUILDER_MODE = build_options.builder_mode;

// TODO (23 Jul 2024 sam): lol
const NUMBER_STR = [_][]const u8{ "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15", "16", "17", "18", "19", "20", "21", "22", "23", "24", "25", "26", "27", "28", "29", "30", "31", "32", "33", "34", "35", "36", "37", "38", "39", "40", "41", "42", "43", "44", "45", "46", "47", "48", "49" };

const OrePatch = struct {
    position: Vec2i,
};

const World = struct {
    size: Vec2 = SCREEN_SIZE,
    center: Vec2 = SCREEN_SIZE.scale(0.5),
    ore_patches: std.ArrayList(OrePatch),

    pub fn init(allocator: std.mem.Allocator) World {
        return .{
            .ore_patches = std.ArrayList(OrePatch).init(allocator),
        };
    }

    pub fn setup(self: *World) void {
        const ORE_POSITIONS = [_]Vec2i{
            .{ .x = 6, .y = 3 },
            .{ .x = -4, .y = -8 },
        };
        for (ORE_POSITIONS) |op| self.ore_patches.append(.{ .position = op }) catch unreachable;
    }

    pub fn deinit(self: *World) void {
        self.ore_patches.deinit();
    }

    pub fn clear(self: *World) void {
        self.ore_patches.clearRetainingCapacity();
        self.center = SCREEN_SIZE.scale(0.5);
    }

    pub fn toScreenPos(self: *const World, position: Vec2) Vec2 {
        var pos = self.center;
        pos.x += position.x;
        pos.y += position.y;
        return pos;
    }

    pub fn fromScreenPos(self: *const World, position: Vec2) Vec2 {
        return position.subtract(self.center);
    }

    pub fn toGridCell(self: *const World, position: Vec2) Vec2i {
        const pos = position;
        _ = self;
        const x = pos.x / GRID_CELL_SIZE.x;
        const y = pos.y / GRID_CELL_SIZE.y;
        const cell = Vec2{ .x = x, .y = y };
        return cell.floorI();
    }

    pub fn gridCenter(self: *const World, cell: Vec2i) Vec2 {
        _ = self;
        const pos = cell.add(GRID_OFFSET);
        const xpos = (@as(f32, @floatFromInt(pos.x)) * GRID_CELL_SIZE.x) + (GRID_CELL_SIZE.x * 0.5);
        const ypos = (@as(f32, @floatFromInt(pos.y)) * GRID_CELL_SIZE.y) + (GRID_CELL_SIZE.y * 0.5);
        return .{ .x = xpos, .y = ypos };
    }

    pub fn maxX(self: *const World) f32 {
        return self.size.x - self.center.x;
    }
    pub fn maxY(self: *const World) f32 {
        return self.size.y - self.center.y;
    }
    pub fn minX(self: *const World) f32 {
        return self.center.x - self.size.x;
    }
    pub fn minY(self: *const World) f32 {
        return self.center.y - self.size.y;
    }

    pub fn clampInBounds(self: *const World, position: Vec2) Vec2 {
        var clamped = position;
        clamped.x = @min(clamped.x, self.maxX());
        clamped.y = @min(clamped.y, self.maxY());
        clamped.x = @max(clamped.x, self.minX());
        clamped.y = @max(clamped.y, self.minY());
        return clamped;
    }
};

const Player = struct {
    position: Vec2 = .{},
    velocity: Vec2 = .{},
    address: Vec2i = .{},
    action_available: ?Action = null,
    target: ?ShadowIndex = null,
    target_countdown: usize = 0,
    actor: Actor = .{},

    pub fn reset(self: *Player) void {
        self.* = .{};
    }

    pub fn clampVelocity(self: *Player) void {
        const vel_sqr = self.velocity.lengthSqr();
        if (vel_sqr < PLAYER_VELOCITY_MAX_SQR) return;
        const vel = @sqrt(vel_sqr);
        const scale = PLAYER_VELOCITY_MAX / vel;
        self.velocity = self.velocity.scale(scale);
    }

    pub fn updatePosition(self: *Player, world: World) void {
        self.position = self.position.add(self.velocity);
        self.position = world.clampInBounds(self.position);
        self.position = self.position.round();
        self.address = world.toGridCell(self.position);
        if (self.target_countdown > 0) {
            self.target_countdown -= 1;
        } else {
            self.target = null;
        }
    }

    pub fn dampVelocity(self: *Player) void {
        self.velocity = self.velocity.scale(PLAYER_VELOCITY_DAMPING);
        self.position = self.position.round();
    }

    pub fn cannotTarget(self: *const Player) bool {
        return self.target_countdown > 0;
    }
};

const SlotType = enum {
    action,
    pickup,
    dropoff,

    pub fn isBlocking(self: *const SlotType) bool {
        return switch (self.*) {
            .action, .pickup => true,
            .dropoff => false,
        };
    }
};

pub const StructureType = enum {
    base,
    mine,
};

pub const Structure = struct {
    structure: StructureType,
    position: Vec2i,
    orientation: Orientation = .n,
    slots: [4]?SlotType = [_]?SlotType{null} ** 4,

    fn setup(self: *Structure) void {
        switch (self.structure) {
            .base => {
                self.slots[0] = .dropoff;
                self.slots[1] = .dropoff;
                self.slots[2] = .dropoff;
                self.slots[3] = .dropoff;
            },
            .mine => {
                self.slots[self.orientation.toIndex()] = .pickup;
                self.slots[self.orientation.opposite().toIndex()] = .action;
            },
        }
    }
};

const ResourceType = enum {
    lead,
    tin,
    iron,
};
const RESOURCE_COUNT = @typeInfo(ResourceType).Enum.fields.len;

const Resource = struct {
    resource: ResourceType,
    position: Vec2i,
};

const Path = struct {
    // all loops are closed loops. points has first and last as same element
    points: std.ArrayList(Vec2i),
    cells: std.ArrayList(Vec2i),

    pub fn init(allocator: std.mem.Allocator) Path {
        return .{
            .points = std.ArrayList(Vec2i).init(allocator),
            .cells = std.ArrayList(Vec2i).init(allocator),
        };
    }
    pub fn deinit(self: *Path) void {
        self.points.deinit();
        self.cells.deinit();
    }

    pub fn clear(self: *Path) void {
        self.points.clearRetainingCapacity();
        self.cells.clearRetainingCapacity();
    }

    pub fn copy(self: *Path, other: Path) void {
        self.points.appendSlice(other.points.items) catch unreachable;
        self.cells.appendSlice(other.points.items) catch unreachable;
    }

    pub fn generateCells(self: *Path) void {
        self.cells.clearRetainingCapacity();
        helpers.assert(self.points.items.len > 1);
        for (0..self.points.items.len - 1) |i| {
            const p0 = self.points.items[i];
            const p1 = self.points.items[i + 1];
            const change = p0.getChangeTo(p1);
            var cell = p0;
            while (!cell.equal(p1)) : (cell = cell.add(change)) {
                self.cells.append(cell) catch unreachable;
            }
        }
    }

    pub fn getLastOrNull(self: *const Path) ?Vec2i {
        return self.points.getLastOrNull();
    }

    // if invalid, returns error point
    pub fn validPathPosition(self: *const Path, p0_opt: ?Vec2i, p1: Vec2i) ?Vec2i {
        if (p0_opt == null) return null;
        if (self.points.items.len < 2) return null;
        if (p1.equal(self.getLastOrNull().?)) return p1;
        const p0 = p0_opt.?;
        for (0..self.points.items.len - 1) |i| {
            const q0 = self.points.items[i];
            const q1 = self.points.items[i + 1];
            if (helpers.linesIntersectNotStart(p0, p1, q0, q1)) |point| {
                // // TODO (20 Jul 2024 sam): Bug here. if you have a line that overlaps with the
                // starting point, and the collision ahppens at point0, then there is a false valid.
                if (!point.equal(self.points.items[0])) return point;
            }
        }
        return null;
    }

    // only called for existing paths
    pub fn pathContains(self: *const Path, p: Vec2i) ?Vec2i {
        for (0..self.points.items.len - 1) |i| {
            const q0 = self.points.items[i];
            const q1 = self.points.items[i + 1];
            if (helpers.lineContains(q0, q1, p)) {
                return p;
            }
        }
        return null;
    }

    pub fn addPoint(self: *Path, address: Vec2i) void {
        helpers.debugPrint("adding point {d},{d}", .{ address.x, address.y });
        self.points.append(address) catch unreachable;
    }
};

pub const BuilderMode = enum {
    menu,
    path_create,
    path_delete,
    djinn_manage,
    build,

    pub fn hidesMenu(self: *const BuilderMode) bool {
        return switch (self.*) {
            .menu => false,
            .path_create,
            .path_delete,
            .djinn_manage,
            .build,
            => true,
        };
    }
};

pub const Builder = struct {
    mode: BuilderMode = .menu,
    position: Vec2i = .{},
    orientation: Orientation = .n,
    current_path: Path,
    target: Vec2i = .{},
    invalid: ?Vec2i = null,
    can_build: bool = false,
    hide_menu: bool = false,

    pub fn init(allocator: std.mem.Allocator) Builder {
        return .{
            .current_path = Path.init(allocator),
        };
    }

    pub fn reset(self: *Builder) void {
        self.current_path.clear();
        self.mode = .menu;
        self.orientation = .n;
    }

    pub fn deinit(self: *Builder) void {
        self.current_path.deinit();
    }
};

pub const Action = struct {
    address: Vec2i,
    structure: StructureIndex,
    slot_index: usize,
    can_be_done: bool,
    blocking: bool,
};

pub const Actor = struct {
    carrying: ?ResourceType = null,
    energy: u8 = ENERGY_DEFAULT_VALUE,
    total_energy: u8 = ENERGY_DEFAULT_VALUE,
};

pub const Djinn = struct {
    position: Vec2,
    address: Vec2i,
    path: ?PathIndex = null,
    cell_index: usize,
    target_address: Vec2i = .{},
    anim_start_pos: Vec2 = .{},
    anim_end_pos: Vec2 = .{},
    actor: Actor = .{},

    pub fn update(self: *Djinn, game: *Game) void {
        if (self.path == null) {
            self.position = SCREEN_SIZE.scale(2);
            return;
        }
        var should_move = true;
        if (game.actionAvailable(self.target_address, self.actor)) |action| {
            if (!action.can_be_done and action.blocking) {
                should_move = false;
            } else {
                game.doAction(action, &self.actor);
            }
        }
        const path = game.paths.getPtr(self.path.?);
        self.anim_start_pos = self.anim_end_pos;
        if (self.actor.energy == 0 and self.actor.carrying == null) {
            self.anim_end_pos = game.world.gridCenter(.{});
            return;
        }
        self.address = self.target_address;
        if (should_move) {
            self.cell_index += 1;
        }
        if (self.cell_index == path.cells.items.len) self.cell_index = 0;
        self.target_address = path.cells.items[self.cell_index];
        self.anim_end_pos = game.world.gridCenter(self.target_address);
    }

    pub fn lerpPosition(self: *Djinn, t: f32) void {
        if (self.path == null) {
            self.position = SCREEN_SIZE.scale(2);
            return;
        }
        self.position = self.anim_start_pos.lerp(self.anim_end_pos, t);
    }
};

pub const DjinnSystem = struct {
    djinns: ConstIndexArray(DjinnIndex, Djinn),
    ticks: usize = 0,

    pub fn init(allocator: std.mem.Allocator) DjinnSystem {
        return .{
            .djinns = ConstIndexArray(DjinnIndex, Djinn).init(allocator),
        };
    }

    pub fn deinit(self: *DjinnSystem) void {
        self.djinns.deinit();
    }

    pub fn reset(self: *DjinnSystem) void {
        self.ticks = 0;
        self.djinns.clearRetainingCapacity();
    }

    pub fn pathCount(self: *DjinnSystem, pkey: PathIndex) usize {
        var count: usize = 0;
        for (self.djinns.items()) |djinn| {
            if (djinn.path != null and djinn.path.?.equal(pkey)) count += 1;
        }
        return count;
    }

    pub fn addToPath(self: *DjinnSystem, pkey: PathIndex, game: *const Game) void {
        const path = game.paths.getPtr(pkey);
        const index = self.pathCount(pkey);
        for (self.djinns.items()) |*djinn| {
            if (djinn.path == null) {
                djinn.path = pkey;
                djinn.cell_index = index;
                djinn.position = game.world.gridCenter(path.cells.items[index]);
                return;
            }
        }
    }

    pub fn removeFromPath(self: *DjinnSystem, pkey: PathIndex, game: *const Game) void {
        _ = game;
        for (self.djinns.items()) |*djinn| {
            if (djinn.path != null and djinn.path.?.equal(pkey)) {
                djinn.path = null;
                djinn.position = SCREEN_SIZE.scale(2);
                return;
            }
        }
    }

    pub fn availableDjinnCount(self: *DjinnSystem) usize {
        const count: usize = 0;
        for (self.djinns.items()) |*djinn| {
            if (djinn.path == null) {
                count += 1;
            }
        }
        return count;
    }

    pub fn totalDjinnCount(self: *DjinnSystem) usize {
        return self.djinns.count();
    }

    pub fn removePath(self: *DjinnSystem, pkey: PathIndex) void {
        for (self.djinns.items()) |*djinn| {
            if (djinn.path != null and djinn.path.?.equal(pkey)) {
                djinn.path = null;
                djinn.position = SCREEN_SIZE.scale(2);
            }
        }
    }

    pub fn update(self: *DjinnSystem, game: *Game) void {
        defer self.ticks += 1;
        if (self.ticks % DJINN_TICK_COUNT == 0) {
            for (self.djinns.items()) |*djinn| {
                djinn.update(game);
            }
        }
        const t: f32 = @as(f32, @floatFromInt(self.ticks % DJINN_TICK_COUNT)) / DJINN_TICK_COUNT;
        for (self.djinns.items()) |*djinn| djinn.lerpPosition(t);
    }
};

pub const Shadow = struct {
    position: Vec2,
    target: ?Vec2 = null,
    velocity: Vec2 = .{},
    scared: ?u16 = null,
    trapped: ?TrapIndex = null,
    carrying: ?SpiritIndex = null,
    dead: bool = false,

    pub fn init(position: Vec2) Shadow {
        return .{
            .position = position,
        };
    }

    pub fn update(self: *Shadow) void {
        if (self.dead) return;
        if (self.scared) |st| {
            self.scared = st + 1;
            if (self.scared.? >= SHADOW_SCARED_TICKS) {
                self.scared = null;
                self.velocity = .{};
            }
        }
        self.position = self.position.add(self.velocity);
    }

    pub fn scare(self: *Shadow, anti_target: Vec2) void {
        self.velocity = self.position.subtract(anti_target).normalize().scale(SHADOW_VELOCITY_SCARED);
        self.scared = 0;
        self.target = null;
        self.carrying = null;
    }
};

pub const ShadowSystem = struct {
    shadows: ConstIndexArray(ShadowIndex, Shadow),

    pub fn init(allocator: std.mem.Allocator) ShadowSystem {
        return .{
            .shadows = ConstIndexArray(ShadowIndex, Shadow).init(allocator),
        };
    }

    pub fn deinit(self: *ShadowSystem) void {
        self.shadows.deinit();
    }

    pub fn clear(self: *ShadowSystem) void {
        self.shadows.clearRetainingCapacity();
    }

    pub fn reset(self: *ShadowSystem) void {
        self.clear();
    }

    pub fn addShadow(self: *ShadowSystem, position: Vec2) void {
        const shadow = Shadow.init(position);
        self.shadows.append(shadow) catch unreachable;
    }

    pub fn allDead(self: *const ShadowSystem) bool {
        for (self.shadows.constItems()) |shadow| {
            if (!shadow.dead) return false;
        }
        return true;
    }

    pub fn update(self: *ShadowSystem, game: *Game) void {
        if (game.player.target) |skey| {
            const shadow = self.shadows.getPtr(skey);
            if (shadow.trapped == null) {
                if (helpers.pointToRectDistanceSqr(game.player.position, shadow.position, SHADOW_SIZE) < PLAYER_LIGHT_RADIUS_SQR) {
                    if (shadow.carrying) |spkey| game.spirits.getPtr(spkey).shadow = null;
                    shadow.scare(game.player.position);
                    game.player.target_countdown = PLAYER_TARGET_RESET_TICKS;
                }
            }
        }
        for (self.shadows.keys()) |skey| {
            if (game.player.cannotTarget()) break;
            const shadow = self.shadows.getPtr(skey);
            if (shadow.dead or shadow.trapped != null) continue;
            if (helpers.pointToRectDistanceSqr(game.player.position, shadow.position, SHADOW_SIZE) < PLAYER_LIGHT_RADIUS_SQR) {
                if (shadow.carrying) |spkey| game.spirits.getPtr(spkey).shadow = null;
                shadow.scare(game.player.position);
                game.player.target = skey;
                game.player.target_countdown = PLAYER_TARGET_RESET_TICKS;
            }
        }
        for (self.shadows.keys()) |skey| {
            const shadow = self.shadows.getPtr(skey);
            if (shadow.dead or shadow.trapped != null) continue;
            if (shadow.scared == null and shadow.target == null) {
                const spirit_index = game.closestSpirit(shadow.position);
                shadow.target = game.spirits.getPtr(spirit_index).position;
                shadow.velocity = shadow.target.?.subtract(shadow.position).normalize().scale(SHADOW_VELOCITY_MAX);
            }
            shadow.update();
            if (shadow.trapped != null) continue;
            if (game.inTrapBounds(shadow.position)) |tkey| {
                const trap = game.traps.getPtr(tkey);
                trap.trapShadow(skey);
                shadow.position = trap.position;
                shadow.trapped = tkey;
                shadow.velocity = .{};
                shadow.target = null;
                if (shadow.carrying) |spkey| {
                    game.spirits.getPtr(spkey).shadow = null;
                }
                shadow.carrying = null;
            }
            if (shadow.target) |target| {
                if (shadow.carrying) |spirit_index| {
                    game.spirits.getPtr(spirit_index).position = shadow.position;
                } else {
                    if (shadow.position.distanceSqr(target) < SHADOW_PICKUP_RADIUS_SQR) {
                        const spirit_index = game.closestSpirit(shadow.position);
                        const spirit = game.spirits.getPtr(spirit_index);
                        if (spirit.shadow == null and shadow.position.distanceSqr(spirit.position) < SHADOW_PICKUP_RADIUS_SQR) {
                            spirit.shadow = skey;
                            shadow.carrying = spirit_index;
                            shadow.velocity = shadow.velocity.scale(-1);
                        } else {
                            shadow.target = null;
                        }
                    }
                }
            }
        }
    }
};

pub const GameMode = enum {
    sunrise,
    day,
    sunset,
    night,
    lost,
};

// magical things that the shadows are trying to steal.
pub const Spirit = struct {
    position: Vec2,
    shadow: ?ShadowIndex = null,
};

pub const Trap = struct {
    position: Vec2,
    shadow: ?ShadowIndex = null,
    count: usize = 0,

    pub fn trapShadow(self: *Trap, shadow: ShadowIndex) void {
        self.shadow = shadow;
        self.count = TRAP_TICKS;
    }

    pub fn update(self: *Trap, game: *Game) void {
        if (self.count > 0) self.count -= 1;
        if (self.count == 0 and self.shadow != null) {
            game.shadows.shadows.getPtr(self.shadow.?).dead = true;
            self.shadow = null;
        }
    }
};

const MenuAction = enum {
    none,
    set_mode_build_mine,
    set_mode_path_create,
    set_mode_path_delete,
    set_mode_djinn_manage,
    action_path_delete,
    action_djinn_remove,
    action_djinn_add,
    action_start_day,
    hide_menu,
};

const MenuText = struct {
    position: Vec2,
    text: []const u8,
    color: Vec4,
    font: []const u8 = FONTS[0],
};

const MenuItem = union(enum) {
    rect: Rect,
    button: Button,
    text: MenuText,
};

pub const Game = struct {
    haathi: *Haathi,
    ticks: u64 = 0,
    world: World,
    resources: std.ArrayList(Resource),
    structures: ConstIndexArray(StructureIndex, Structure),
    paths: ConstIndexArray(PathIndex, Path),
    spirits: ConstIndexArray(SpiritIndex, Spirit),
    traps: ConstIndexArray(TrapIndex, Trap),
    inventory: [RESOURCE_COUNT]u16 = [_]u16{0} ** RESOURCE_COUNT,
    djinns: DjinnSystem,
    shadows: ShadowSystem,
    player: Player = .{},
    builder: Builder,
    mode: GameMode = .day,
    stone_index: SpiritIndex = undefined,
    ff_mode: if (BUILDER_MODE) bool else void = if (BUILDER_MODE) false else {},
    menu: std.ArrayList(MenuItem),
    contextual: std.ArrayList(MenuItem),

    allocator: std.mem.Allocator,
    arena_handle: std.heap.ArenaAllocator,
    arena: std.mem.Allocator,

    pub fn init(haathi: *Haathi) Game {
        const allocator = haathi.allocator;
        var arena_handle = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        const world = World.init(haathi.allocator);
        return .{
            .haathi = haathi,
            .structures = ConstIndexArray(StructureIndex, Structure).init(allocator),
            .resources = std.ArrayList(Resource).init(allocator),
            .paths = ConstIndexArray(PathIndex, Path).init(allocator),
            .spirits = ConstIndexArray(SpiritIndex, Spirit).init(allocator),
            .traps = ConstIndexArray(TrapIndex, Trap).init(allocator),
            .builder = Builder.init(allocator),
            .djinns = DjinnSystem.init(allocator),
            .shadows = ShadowSystem.init(allocator),
            .world = world,
            .menu = std.ArrayList(MenuItem).init(allocator),
            .contextual = std.ArrayList(MenuItem).init(allocator),
            .allocator = allocator,
            .arena_handle = arena_handle,
            .arena = arena_handle.allocator(),
        };
    }

    pub fn deinit(self: *Game) void {
        self.builder.deinit();
        self.djinns.deinit();
        self.shadows.deinit();
        self.structures.deinit();
        self.resources.deinit();
        self.spirits.deinit();
        for (self.paths.items()) |*path| path.deinit();
        self.paths.deinit();
        self.world.deinit();
        self.traps.deinit();
        self.menu.deinit();
        self.contextual.deinit();
    }

    fn clear(self: *Game) void {
        self.builder.reset();
        self.djinns.reset();
        self.shadows.reset();
        self.structures.clearRetainingCapacity();
        self.resources.clearRetainingCapacity();
        self.spirits.clearRetainingCapacity();
        for (self.paths.items()) |*path| path.deinit();
        self.paths.clearRetainingCapacity();
        self.world.clear();
        self.traps.clearRetainingCapacity();
        self.menu.clearRetainingCapacity();
        self.contextual.clearRetainingCapacity();
    }

    fn reset(self: *Game) void {
        self.clear();
        self.setup();
    }

    pub fn setup(self: *Game) void {
        self.mode = .day;
        self.structures.append(.{ .structure = .base, .position = .{} }) catch unreachable;
        self.structures.append(.{ .structure = .mine, .position = .{ .x = 6, .y = 3 } }) catch unreachable;
        for (self.structures.items()) |*str| str.setup();
        self.world.setup();
        const pkey = self.paths.getNextKey();
        {
            var path = Path.init(self.haathi.allocator);
            path.addPoint(.{ .x = 1, .y = 2 });
            path.addPoint(.{ .x = 7, .y = 2 });
            path.addPoint(.{ .x = 7, .y = 4 });
            path.addPoint(.{ .x = 0, .y = 4 });
            path.addPoint(.{ .x = 0, .y = 1 });
            path.addPoint(.{ .x = 1, .y = 1 });
            path.addPoint(.{ .x = 1, .y = 2 });
            self.addPath(path);
        }
        {
            self.addDjinn(pkey, 2);
            self.addDjinn(pkey, 1);
            self.addDjinn(pkey, 0);
        }
        {
            self.shadows.addShadow(SCREEN_SIZE.scale(-0.5));
            self.shadows.addShadow(SCREEN_SIZE.scale(-0.5).add(.{ .x = 40 }));
            self.shadows.addShadow(SCREEN_SIZE.scale(0.5).add(.{ .y = 40 }));
            self.shadows.addShadow(SCREEN_SIZE.scale(0.5).add(.{ .x = 40 }));
        }
        {
            self.stone_index = self.spirits.getNextKey();
            self.spirits.append(.{ .position = .{ .x = 0 } }) catch unreachable;
        }
        {
            self.traps.append(.{ .position = .{ .y = 100 } }) catch unreachable;
            self.traps.append(.{ .position = .{ .y = -100 } }) catch unreachable;
        }
        {
            self.setupSunriseMenu();
        }
    }

    fn setupSunriseMenu(self: *Game) void {
        self.menu.clearRetainingCapacity();
        const sx = SCREEN_SIZE.x;
        const sy = SCREEN_SIZE.y;
        self.menu.append(.{
            .text = .{
                .text = "You survived the night.",
                .position = .{ .x = sx * 0.5, .y = sy * 0.8 },
                .color = colors.solarized_base03,
            },
        }) catch unreachable;
        self.menu.append(.{
            .rect = .{
                .position = .{ .x = sx * 0.3, .y = sy * 0.4 },
                .size = .{ .x = sx * 0.4, .y = sy * 0.3 },
            },
        }) catch unreachable;
        var current_pos = Vec2{ .x = sx * 0.3 + 20, .y = sy * 0.7 - 40 };
        self.menu.append(.{
            .button = .{
                .rect = .{
                    .position = current_pos,
                    .size = .{ .x = 160, .y = 25 },
                },
                .value = @intFromEnum(MenuAction.set_mode_build_mine),
                .text = "Build Mine",
            },
        }) catch unreachable;
        current_pos = current_pos.add(.{ .y = -40 });
        self.menu.append(.{
            .button = .{
                .rect = .{
                    .position = current_pos,
                    .size = .{ .x = 160, .y = 25 },
                },
                .value = @intFromEnum(MenuAction.set_mode_path_create),
                .text = "Create Path",
            },
        }) catch unreachable;
        current_pos = current_pos.add(.{ .y = -40 });
        self.menu.append(.{
            .button = .{
                .rect = .{
                    .position = current_pos,
                    .size = .{ .x = 160, .y = 25 },
                },
                .value = @intFromEnum(MenuAction.set_mode_path_delete),
                .text = "Delete Path",
            },
        }) catch unreachable;
        current_pos = current_pos.add(.{ .y = -40 });
        self.menu.append(.{
            .button = .{
                .rect = .{
                    .position = current_pos,
                    .size = .{ .x = 160, .y = 25 },
                },
                .value = @intFromEnum(MenuAction.set_mode_djinn_manage),
                .text = "Manage Djinn",
            },
        }) catch unreachable;
        current_pos = current_pos.add(.{ .y = -40 });
        self.menu.append(.{
            .button = .{
                .rect = .{
                    .position = current_pos,
                    .size = .{ .x = 160, .y = 25 },
                },
                .value = @intFromEnum(MenuAction.action_start_day),
                .text = "Start Day",
            },
        }) catch unreachable;
        current_pos = Vec2{ .x = sx * 0.3 + 200, .y = sy * 0.7 - 40 };
        self.menu.append(.{
            .button = .{
                .rect = .{
                    .position = current_pos,
                    .size = .{ .x = 160, .y = 25 },
                },
                .value = @intFromEnum(MenuAction.hide_menu),
                .text = "View World",
            },
        }) catch unreachable;
    }

    fn inTrapBounds(self: *Game, position: Vec2) ?TrapIndex {
        for (self.traps.keys()) |tkey| {
            const trap = self.traps.getPtr(tkey);
            if (trap.shadow != null) continue;
            if (trap.position.distanceSqr(position) < TRAP_RADIUS_SQR) return tkey;
        }
        return null;
    }

    fn closestSpirit(self: *const Game, position: Vec2) SpiritIndex {
        var closest_spirit: SpiritIndex = undefined;
        var closest_distance_sqr = SCREEN_SIZE.x * SCREEN_SIZE.x * 1000000;
        for (self.spirits.keys()) |skey| {
            const spirit = self.spirits.getPtr(skey);
            const distance = spirit.position.distanceSqr(position);
            if (distance < closest_distance_sqr) {
                closest_distance_sqr = distance;
                closest_spirit = skey;
            }
        }
        return closest_spirit;
    }

    fn actionAvailable(self: *Game, address: Vec2i, actor: Actor) ?Action {
        // check if address is slot
        const is_carrying = actor.carrying != null;
        for (self.structures.keys()) |skey| {
            const str = self.structures.getPtr(skey);
            if (address.distancei(str.position) != 1) continue;
            const slot_orientation = Orientation.getRelative(str.position, address);
            const slot_opt = str.slots[slot_orientation.toIndex()];
            if (slot_opt == null) continue;
            const slot = slot_opt.?;
            switch (slot) {
                .pickup => {
                    const has_resource = self.hasResource(address);
                    return .{
                        .address = address,
                        .structure = skey,
                        .slot_index = slot_orientation.toIndex(),
                        .can_be_done = actor.energy > 0 and has_resource != null,
                        .blocking = slot.isBlocking(),
                    };
                },
                .dropoff => {
                    return .{
                        .address = address,
                        .structure = skey,
                        .slot_index = slot_orientation.toIndex(),
                        .can_be_done = is_carrying,
                        .blocking = slot.isBlocking(),
                    };
                },
                .action => {
                    switch (str.structure) {
                        .mine => {
                            // can only do action if there is no resource in the pickup slot
                            const has_resource = self.hasResource(str.position.add(str.orientation.toDir()));
                            return .{
                                .address = address,
                                .structure = skey,
                                .slot_index = slot_orientation.toIndex(),
                                .can_be_done = has_resource == null and actor.energy > 0,
                                .blocking = slot.isBlocking(),
                            };
                        },
                        .base => unreachable,
                    }
                },
            }
        }
        return null;
    }

    fn hasResource(self: *const Game, address: Vec2i) ?ResourceType {
        for (self.resources.items) |rsc| {
            if (rsc.position.equal(address)) return rsc.resource;
        }
        return null;
    }

    fn removeResource(self: *Game, address: Vec2i) void {
        for (self.resources.items, 0..) |rsc, i| {
            if (rsc.position.equal(address)) {
                _ = self.resources.swapRemove(i);
                return;
            }
        }
        unreachable;
    }

    fn doAction(self: *Game, action: Action, actor: *Actor) void {
        if (!action.can_be_done) return;
        helpers.debugPrint("action at {d},{d}", .{ action.address.x, action.address.y });
        const str = self.structures.getPtr(action.structure);
        const slot = str.slots[action.slot_index].?;
        switch (slot) {
            .pickup => {
                const has_resource = self.hasResource(action.address);
                helpers.assert(has_resource != null);
                actor.carrying = has_resource;
                actor.energy -= 1;
                self.removeResource(action.address);
            },
            .dropoff => {
                const has_resource = self.hasResource(action.address);
                helpers.assert(has_resource == null);
                helpers.assert(actor.carrying != null);
                self.inventory[@intFromEnum(actor.carrying.?)] += 1;
                actor.carrying = null;
            },
            .action => {
                switch (str.structure) {
                    .mine => {
                        // can only do action if there is no resource in the pickup slot
                        const output_spot = str.position.add(str.orientation.toDir());
                        const has_resource = self.hasResource(output_spot);
                        helpers.assert(has_resource == null);
                        self.resources.append(.{ .resource = .lead, .position = output_spot }) catch unreachable;
                        actor.energy -= 1;
                    },
                    .base => unreachable,
                }
            },
        }
    }

    fn doMenuAction(self: *Game, action: MenuAction, index: usize) void {
        switch (action) {
            .none, .hide_menu => {},
            .set_mode_build_mine => {
                self.builder.mode = .build;
            },
            .set_mode_path_create => {
                self.builder.mode = .path_create;
            },
            .set_mode_path_delete => {
                self.builder.mode = .path_delete;
                self.setupContextual();
            },
            .set_mode_djinn_manage => {
                self.builder.mode = .djinn_manage;
                self.setupContextual();
            },
            .action_path_delete => {
                const path_index = PathIndex{ .index = index };
                self.deletePath(path_index);
                self.setupContextual();
            },
            .action_djinn_remove => {
                self.djinns.removeFromPath(.{ .index = index }, self);
                self.setupContextual();
            },
            .action_djinn_add => {
                self.djinns.addToPath(.{ .index = index }, self);
                self.setupContextual();
            },
            .action_start_day => {
                self.mode = .day;
            },
        }
    }

    fn deletePath(self: *Game, path_index: PathIndex) void {
        self.paths.delete(path_index);
        self.djinns.removePath(path_index);
    }

    fn setupContextual(self: *Game) void {
        self.contextual.clearRetainingCapacity();
        switch (self.builder.mode) {
            .path_delete => {
                for (self.paths.keys()) |pkey| {
                    const path = self.paths.getPtr(pkey);
                    const start = path.points.items[0];
                    const pos = self.world.gridCenter(start);
                    self.contextual.append(.{ .button = .{
                        .rect = .{
                            .position = pos.add(.{ .x = -30, .y = GRID_CELL_SIZE.y * -0.65 }),
                            .size = .{ .x = 60, .y = 25 },
                        },
                        .text = "delete",
                        .value = @intFromEnum(MenuAction.action_path_delete),
                        .index = pkey.index,
                    } }) catch unreachable;
                }
            },
            .djinn_manage => {
                for (self.paths.keys()) |pkey| {
                    const path = self.paths.getPtr(pkey);
                    const start = path.points.items[0];
                    const pos = self.world.gridCenter(start);
                    self.contextual.append(.{
                        .text = .{
                            .text = NUMBER_STR[self.djinns.pathCount(pkey)],
                            .position = pos.add(.{ .y = 2 }),
                            .color = colors.solarized_base03,
                        },
                    }) catch unreachable;
                    self.contextual.append(.{ .button = .{
                        .rect = .{
                            .position = pos.add(.{ .x = -28, .y = GRID_CELL_SIZE.y * -0.65 }),
                            .size = .{ .x = 25, .y = 25 },
                        },
                        .text = "-",
                        .value = @intFromEnum(MenuAction.action_djinn_remove),
                        .index = pkey.index,
                    } }) catch unreachable;
                    self.contextual.append(.{ .button = .{
                        .rect = .{
                            .position = pos.add(.{ .x = 0, .y = GRID_CELL_SIZE.y * -0.65 }),
                            .size = .{ .x = 25, .y = 25 },
                        },
                        .text = "+",
                        .value = @intFromEnum(MenuAction.action_djinn_add),
                        .index = pkey.index,
                    } }) catch unreachable;
                }
            },
            else => {},
        }
    }

    // updateGame
    pub fn update(self: *Game, ticks: u64) void {
        // clear the arena and reset.
        _ = self.arena_handle.reset(.retain_capacity);
        self.arena = self.arena_handle.allocator();
        self.ticks = ticks;
        const address = self.world.toGridCell(self.world.fromScreenPos(self.haathi.inputs.mouse.current_pos));
        var moving = false;
        if (self.haathi.inputs.getKey(.w).is_down) {
            self.player.velocity.y += PLAYER_ACCELERATION;
            moving = true;
        }
        if (self.haathi.inputs.getKey(.s).is_down) {
            self.player.velocity.y -= PLAYER_ACCELERATION;
            moving = true;
        }
        if (self.haathi.inputs.getKey(.d).is_down) {
            self.player.velocity.x += PLAYER_ACCELERATION;
            moving = true;
        }
        if (self.haathi.inputs.getKey(.a).is_down) {
            self.player.velocity.x -= PLAYER_ACCELERATION;
            moving = true;
        }
        self.player.clampVelocity();
        self.player.updatePosition(self.world);
        if (!moving) self.player.dampVelocity();
        if (BUILDER_MODE) {
            if (self.haathi.inputs.getKey(.num_1).is_down) self.ff_mode = true;
        }
        switch (self.mode) {
            .day => {
                self.player.action_available = self.actionAvailable(self.player.address, self.player.actor);
                if (self.player.address.equal(address)) {
                    if (self.player.action_available != null and self.player.action_available.?.can_be_done and self.haathi.inputs.mouse.l_button.is_clicked) {
                        self.doAction(self.player.action_available.?, &self.player.actor);
                    }
                }
                if (BUILDER_MODE) {
                    if (self.haathi.inputs.getKey(.m).is_clicked) self.mode = .sunset;
                }
                self.djinns.update(self);
            },
            .sunset => {
                if (BUILDER_MODE) {
                    if (self.haathi.inputs.getKey(.m).is_clicked) self.mode = .night;
                }
            },
            .night => {
                self.player.action_available = null;
                self.shadows.update(self);
                for (self.traps.items()) |*trap| trap.update(self);
                self.checkLoseScenario();
                self.checkWinScenario();
                if (BUILDER_MODE) {
                    if (self.haathi.inputs.getKey(.m).is_clicked) self.mode = .sunrise;
                    if (self.haathi.inputs.getKey(.n).is_clicked) {
                        const position = self.world.fromScreenPos(self.haathi.inputs.mouse.current_pos);
                        helpers.debugPrint("{any}", .{self.inTrapBounds(position)});
                    }
                }
            },
            .lost => {
                if (self.haathi.inputs.getKey(.enter).is_clicked) self.reset();
            },
            .sunrise => {
                switch (self.builder.mode) {
                    .menu => {
                        if (BUILDER_MODE) {
                            if (self.haathi.inputs.getKey(.p).is_clicked) {
                                self.builder.mode = .path_create;
                            }
                            if (self.haathi.inputs.getKey(.o).is_clicked) {
                                self.builder.mode = .djinn_manage;
                            }
                            if (self.haathi.inputs.getKey(.i).is_clicked) {
                                self.builder.mode = .build;
                            }
                        }
                    },
                    .path_create => {
                        self.builder.target = if (self.builder.current_path.points.items.len > 0) self.builder.current_path.getLastOrNull().?.orthoTarget(address) else address;
                        const prev = self.builder.current_path.getLastOrNull();
                        self.builder.invalid = self.validPathPosition(prev, self.builder.target);
                        if (self.builder.invalid == null) self.builder.invalid = self.builder.current_path.validPathPosition(prev, self.builder.target);
                        if (self.haathi.inputs.mouse.l_button.is_clicked) {
                            const completes = self.builder.current_path.points.items.len > 0 and self.builder.current_path.points.items[0].equal(self.builder.target);
                            if (self.builder.invalid == null) {
                                self.builder.current_path.addPoint(self.builder.target);
                                if (completes) {
                                    if (self.builder.current_path.points.items.len > 2) self.addPath(self.builder.current_path);
                                    self.builder.mode = .menu;
                                    self.builder.current_path.clear();
                                }
                            }
                        }
                        if (self.haathi.inputs.getKey(.escape).is_clicked) {
                            self.builder.mode = .menu;
                            self.builder.current_path.clear();
                            self.setupContextual();
                        }
                    },
                    .path_delete => {
                        if (self.haathi.inputs.getKey(.escape).is_clicked) {
                            self.builder.mode = .menu;
                            self.builder.current_path.clear();
                            self.setupContextual();
                        }
                    },
                    .djinn_manage => {
                        if (self.haathi.inputs.getKey(.escape).is_clicked) {
                            self.builder.mode = .menu;
                            self.setupContextual();
                        }
                    },
                    .build => {
                        if (self.haathi.inputs.getKey(.r).is_clicked) self.builder.orientation = self.builder.orientation.next();
                        // TODO (20 Jul 2024 sam): Should also check no collisions with other slots / paths?
                        self.builder.can_build = self.isOrePatch(address) and self.getStructure(address) == null;
                        if (self.haathi.inputs.mouse.l_button.is_clicked and self.builder.can_build) {
                            const skey = self.structures.getNextKey();
                            self.structures.append(.{ .structure = .mine, .position = address, .orientation = self.builder.orientation }) catch unreachable;
                            self.structures.getPtr(skey).setup();
                            self.builder.mode = .menu;
                        }
                        if (self.haathi.inputs.getKey(.escape).is_clicked) {
                            self.builder.mode = .menu;
                            self.setupContextual();
                        }
                    },
                }
                self.builder.hide_menu = self.builder.mode.hidesMenu();
                for (self.menu.items) |*item| {
                    if (item.* == .button) {
                        if (!self.builder.hide_menu) {
                            item.button.update(self.haathi.inputs.mouse);
                            if (item.button.clicked) {
                                self.doMenuAction(@enumFromInt(item.button.value), item.button.index);
                            }
                        }
                        if (!self.builder.hide_menu and item.button.value == @intFromEnum(MenuAction.hide_menu)) self.builder.hide_menu = item.button.hovered;
                    }
                }
                for (self.contextual.items) |*item| {
                    if (item.* == .button) {
                        item.button.update(self.haathi.inputs.mouse);
                        if (item.button.clicked) {
                            self.doMenuAction(@enumFromInt(item.button.value), item.button.index);
                        }
                        if (item.button.value == @intFromEnum(MenuAction.hide_menu)) self.builder.hide_menu = item.button.hovered;
                    }
                }
                if (BUILDER_MODE) {
                    if (self.haathi.inputs.getKey(.m).is_clicked) self.mode = .day;
                }
            },
        }
    }

    fn checkLoseScenario(self: *Game) void {
        const stone_position = self.spirits.getPtr(self.stone_index).position;
        const clamped_position = self.world.clampInBounds(stone_position);
        if (!stone_position.equal(clamped_position)) self.mode = .lost;
    }

    fn checkWinScenario(self: *Game) void {
        // TODO (23 Jul 2024 sam): Add night timer
        if (self.shadows.allDead()) {
            self.mode = .sunrise;
        }
    }

    fn isOrePatch(self: *Game, address: Vec2i) bool {
        for (self.world.ore_patches.items) |patch| {
            if (patch.position.equal(address)) return true;
        }
        return false;
    }

    fn getStructure(self: *Game, address: Vec2i) ?StructureIndex {
        for (self.structures.keys()) |skey| {
            const str = self.structures.getPtr(skey);
            if (str.position.equal(address)) return skey;
        }
        return null;
    }

    fn addDjinn(self: *Game, pkey: PathIndex, index: usize) void {
        const path = self.paths.getPtr(pkey);
        const address = path.cells.items[index];
        // add djinn
        const pos = self.world.gridCenter(address);
        self.djinns.djinns.append(.{ .position = pos, .address = address, .path = pkey, .cell_index = index, .anim_start_pos = pos, .anim_end_pos = pos }) catch unreachable;
        return;
    }

    fn addPath(self: *Game, path_in: Path) void {
        var path = Path.init(self.haathi.allocator);
        path.copy(path_in);
        path.generateCells();
        self.paths.append(path) catch unreachable;
    }

    fn pathStarts(self: *Game, address: Vec2i) ?PathIndex {
        for (self.paths.keys()) |pkey| {
            const path = self.paths.getPtr(pkey);
            if (path.points.items[0].equal(address)) return pkey;
        }
        return null;
    }

    // checks that the path doesn't intersect with structures, or other paths
    pub fn validPathPosition(self: *Game, p0_opt: ?Vec2i, p1: Vec2i) ?Vec2i {
        // TODO (20 Jul 2024 sam): Check intersections with structures.
        if (p0_opt) |p0| {
            for (self.paths.items()) |path| {
                if (path.validPathPosition(p0, p1)) |point| return point;
            }
            return null;
        } else {
            for (self.paths.items()) |path| {
                if (path.pathContains(p1)) |point| return point;
            }
            return null;
        }
    }

    pub fn drawCellInset(self: *Game, address: Vec2i, inset: f32, color: Vec4) void {
        const pos = address.add(GRID_OFFSET);
        const xpos = @as(f32, @floatFromInt(pos.x)) * GRID_CELL_SIZE.x;
        const ypos = @as(f32, @floatFromInt(pos.y)) * GRID_CELL_SIZE.y;
        self.haathi.drawRect(.{
            .position = .{ .x = xpos + inset, .y = ypos + inset },
            .size = GRID_CELL_SIZE.subtract(.{ .x = inset * 2, .y = inset * 2 }),
            .color = color,
        });
    }

    pub fn drawCellBorder(self: *Game, address: Vec2i, width: f32, color: Vec4) void {
        var path = self.haathi.arena.alloc(Vec2, 4) catch unreachable;
        const pos = address.add(GRID_OFFSET);
        const xpos = @as(f32, @floatFromInt(pos.x)) * GRID_CELL_SIZE.x;
        const ypos = @as(f32, @floatFromInt(pos.y)) * GRID_CELL_SIZE.y;
        const hw = width / 2;
        const xdiff = GRID_CELL_SIZE.x - width;
        const ydiff = GRID_CELL_SIZE.y - width;
        path[0] = .{ .x = xpos + hw, .y = ypos + hw };
        path[1] = .{ .x = xpos + hw + xdiff, .y = ypos + hw };
        path[2] = .{ .x = xpos + hw + xdiff, .y = ypos + hw + ydiff };
        path[3] = .{ .x = xpos + hw, .y = ypos + hw + ydiff };
        self.haathi.drawPath(.{
            .points = path,
            .color = color,
            .width = width,
            .closed = true,
        });
    }

    pub fn drawPath(self: *Game, path: Path) void {
        if (path.points.items.len < 2) return;
        for (0..path.points.items.len - 1) |i| {
            const p0 = path.points.items[i];
            const p1 = path.points.items[i + 1];
            if (false) {
                // draw each cell
                const horiz = p0.y == p1.y;
                const p_fixed = p0.orthoFixed(horiz);
                const p_start = @min(p0.orthoVariable(horiz), p1.orthoVariable(horiz));
                const p_end = @max(p0.orthoVariable(horiz), p1.orthoVariable(horiz));
                var v = p_start;
                while (v <= p_end) : (v += 1) {
                    const cell = Vec2i.orthoConstruct(p_fixed, v, horiz);
                    self.drawCellInset(cell, 3, colors.solarized_yellow.alpha(0.4));
                }
            }
            self.haathi.drawLine(.{ .p0 = self.world.gridCenter(p0), .p1 = self.world.gridCenter(p1), .color = colors.solarized_yellow.alpha(0.4), .width = 12 });
        }
    }

    fn drawStructure(self: *Game, str: Structure) void {
        self.drawCellInset(str.position, 6, colors.solarized_blue.alpha(0.8));
        self.haathi.drawText(.{
            .text = @tagName(str.structure),
            .position = self.world.gridCenter(str.position),
            .color = colors.solarized_base03,
            .style = FONTS[1],
        });
        for (str.slots, 0..) |slot, i| {
            if (slot) |stype| {
                const address = str.position.add(Orientation.fromIndex(i).toDir());
                // self.haathi.drawText(.{
                //     .text = @tagName(stype),
                //     .position = self.world.gridCenter(address).add(GRID_CELL_SIZE.yVec().scale(-0.5)),
                //     .color = colors.solarized_base03,
                //     .style = FONTS[1],
                // });
                switch (stype) {
                    .pickup => {
                        self.drawCellInset(address, 5, colors.solarized_green.alpha(0.4));
                    },
                    .dropoff => {
                        self.drawCellInset(address, 5, colors.solarized_cyan.alpha(0.4));
                    },
                    .action => {
                        self.drawCellInset(address, 5, colors.solarized_orange.alpha(0.4));
                    },
                }
            }
        }
    }

    pub fn render(self: *Game) void {
        // background
        self.haathi.drawRect(.{
            .position = .{},
            .size = SCREEN_SIZE,
            .color = colors.solarized_base3,
        });
        // lose_screen
        if (self.mode == .lost) {
            self.haathi.drawText(.{
                .text = "The shadows have stolen the philosophers stone",
                .position = .{ .x = SCREEN_SIZE.x / 2, .y = SCREEN_SIZE.y * 0.75 },
                .color = colors.solarized_base03,
            });
            self.haathi.drawText(.{
                .text = "You have failed your assignment",
                .position = .{ .x = SCREEN_SIZE.x / 2, .y = SCREEN_SIZE.y * 0.65 },
                .color = colors.solarized_base03,
            });
            self.haathi.drawText(.{
                .text = "Press enter to restart",
                .position = .{ .x = SCREEN_SIZE.x / 2, .y = SCREEN_SIZE.y * 0.45 },
                .color = colors.solarized_base03,
            });
            return;
        }
        // draw grid
        for (0..@intCast(GRID_SIZE.x)) |x| {
            for (0..@intCast(GRID_SIZE.y)) |y| {
                const xpos = @as(f32, @floatFromInt(x)) * GRID_CELL_SIZE.x;
                const ypos = @as(f32, @floatFromInt(y)) * GRID_CELL_SIZE.y;
                self.haathi.drawRect(.{
                    .position = .{ .x = xpos + 1, .y = ypos + 1 },
                    .size = GRID_CELL_SIZE.subtract(.{ .x = 2, .y = 2 }),
                    .color = colors.solarized_base2.alpha(0.5),
                });
            }
        }
        // draw ore
        for (self.world.ore_patches.items) |patch| {
            self.drawCellInset(patch.position, 3, colors.solarized_base1.alpha(0.5));
        }
        // draw structures
        for (self.structures.items()) |str| {
            self.drawStructure(str);
        }
        // draw resources
        for (self.resources.items) |rsc| {
            self.drawCellInset(rsc.position, 12, colors.solarized_orange);
        }
        const mouse_address = self.world.toGridCell(self.world.fromScreenPos(self.haathi.inputs.mouse.current_pos));
        if (self.player.action_available != null and self.player.action_available.?.can_be_done) {
            self.drawCellBorder(self.world.toGridCell(self.player.position), 4, colors.solarized_base03);
            const slot = self.structures.getPtr(self.player.action_available.?.structure).slots[self.player.action_available.?.slot_index].?;
            self.haathi.drawText(.{
                .text = @tagName(slot),
                .position = self.world.gridCenter(self.player.action_available.?.address).add(GRID_CELL_SIZE.yVec().scale(0.55)),
                .color = colors.solarized_base03,
            });
        } else {
            if (self.mode == .day) {
                if (self.actionAvailable(mouse_address, .{})) |action| {
                    const slot = self.structures.getPtr(action.structure).slots[action.slot_index].?;
                    self.haathi.drawText(.{
                        .text = @tagName(slot),
                        .position = self.world.gridCenter(mouse_address).add(GRID_CELL_SIZE.yVec().scale(0.55)),
                        .color = colors.solarized_base03.alpha(0.6),
                    });
                }
                self.drawCellBorder(self.world.toGridCell(self.player.position), 1, colors.solarized_base03.alpha(0.3));
            }
        }
        for (self.paths.items()) |path| {
            self.drawPath(path);
        }
        self.drawPath(self.builder.current_path);
        if (self.builder.current_path.getLastOrNull()) |p0| {
            const p1 = self.builder.target;
            self.haathi.drawLine(.{ .p0 = self.world.gridCenter(p0), .p1 = self.world.gridCenter(p1), .color = colors.solarized_yellow.alpha(0.2), .width = 10 });
        }
        if (self.builder.invalid) |cell| self.drawCellInset(cell, 0, colors.solarized_red);
        for (self.djinns.djinns.items()) |djinn| {
            self.haathi.drawRect(.{
                .position = djinn.position.add(DJINN_SIZE.scale(-0.5)),
                .size = DJINN_SIZE,
                .color = colors.solarized_magenta,
            });
            if (djinn.actor.carrying) |_| {
                self.haathi.drawRect(.{
                    .position = djinn.position.add(DJINN_SIZE.scale(-0.5)).add(DJINN_SIZE.yVec()).add(DJINN_SIZE.xVec().scale(0.5)).add(.{ .x = -6, .y = -6 }),
                    .size = .{ .x = 12, .y = 12 },
                    .color = colors.solarized_orange,
                });
            }
        }
        if (self.builder.mode != .menu) self.haathi.drawText(.{ .text = @tagName(self.builder.mode), .position = self.haathi.inputs.mouse.current_pos, .color = colors.solarized_base03 });
        if (self.builder.mode == .path_create) {
            // draw mouse
            self.drawCellInset(mouse_address, 10, colors.solarized_yellow);
            //self.haathi.drawRect(.{
            //    .position = self.haathi.inputs.mouse.current_pos,
            //    .size = .{ .x = 10, .y = 10 },
            //    .color = colors.solarized_orange,
            //});
        }
        if (self.builder.mode == .build) {
            var temp_str = Structure{ .position = mouse_address, .orientation = self.builder.orientation, .structure = .mine };
            temp_str.setup();
            self.drawStructure(temp_str);
            if (!self.builder.can_build) {
                self.drawCellInset(mouse_address, 6, colors.solarized_red);
            }
        }
        if (self.mode == .night) {
            self.haathi.drawRect(.{
                .position = .{},
                .size = SCREEN_SIZE,
                .color = colors.solarized_base03.alpha(0.3),
            });
            // draw player light
            const beam_multiplier = @as(f32, @floatFromInt(self.player.target_countdown)) / PLAYER_TARGET_RESET_TICKS;
            const light_multiplier = 1 - beam_multiplier;
            self.haathi.drawRect(.{
                .position = self.world.toScreenPos(self.player.position),
                .centered = true,
                .radius = PLAYER_LIGHT_RADIUS,
                .size = PLAYER_LIGHT_SIZE,
                .color = colors.solarized_base3.alpha(0.6 * light_multiplier),
            });
            for (self.spirits.items()) |spirit| {
                self.haathi.drawRect(.{
                    .position = self.world.toScreenPos(spirit.position),
                    .centered = true,
                    .radius = SPIRIT_LIGHT_RADIUS,
                    .size = SPIRIT_LIGHT_SIZE,
                    .color = colors.solarized_blue.alpha(0.6),
                });
            }
            if (self.player.target) |skey| {
                const shadow = self.shadows.shadows.getPtr(skey);
                self.haathi.drawLine(.{
                    .p0 = self.world.toScreenPos(self.player.position),
                    .p1 = self.world.toScreenPos(shadow.position),
                    .color = colors.solarized_red.lerp(colors.solarized_base3, 0.8).alpha(beam_multiplier),
                    .width = 12,
                });
            }
            for (self.shadows.shadows.items()) |shadow| {
                if (shadow.dead) continue;
                if (shadow.trapped != null) {
                    self.haathi.drawRect(.{
                        .position = self.world.toScreenPos(shadow.position),
                        .size = SHADOW_SIZE.scale(1.1),
                        .color = colors.white,
                        .centered = true,
                    });
                }
                self.haathi.drawRect(.{
                    .position = self.world.toScreenPos(shadow.position),
                    .size = SHADOW_SIZE,
                    .color = colors.solarized_cyan,
                    .centered = true,
                });
            }
            for (self.spirits.items()) |spirit| {
                self.haathi.drawRect(.{
                    .position = self.world.toScreenPos(spirit.position).add(SPIRIT_SIZE.scale(-0.5)),
                    .size = SPIRIT_SIZE,
                    .color = colors.solarized_blue.lerp(colors.white, 0.5),
                });
            }
            for (self.traps.items()) |trap| {
                self.haathi.drawRect(.{
                    .position = self.world.toScreenPos(trap.position).add(TRAP_SIZE.scale(-0.5)),
                    .size = TRAP_SIZE,
                    .color = colors.solarized_magenta,
                });
                self.haathi.drawText(.{
                    .text = "trap",
                    .position = self.world.toScreenPos(trap.position),
                    .color = colors.white,
                });
                if (trap.shadow != null) {
                    const progress: f32 = (TRAP_TICKS - @as(f32, @floatFromInt(trap.count))) / TRAP_TICKS;
                    {
                        const start = self.world.toScreenPos(trap.position).add(TRAP_SIZE.yVec().scale(0.4)).add(.{ .x = -TRAP_INDICATOR_SIZE / 2 });
                        const end = start.add(.{ .x = TRAP_INDICATOR_SIZE });
                        self.haathi.drawLine(.{ .p0 = start, .p1 = end, .color = colors.solarized_base03, .width = 7 });
                        self.haathi.drawLine(.{ .p0 = start, .p1 = start.lerp(end, progress), .color = colors.solarized_base00, .width = 7 });
                    }
                    {
                        const shadow_size = SHADOW_SIZE.scale(1.0 - progress);
                        self.haathi.drawRect(.{
                            .position = self.world.toScreenPos(trap.position),
                            .size = shadow_size,
                            .color = colors.solarized_cyan,
                            .centered = true,
                        });
                    }
                }
            }
        }
        // draw player
        self.haathi.drawRect(.{
            .position = self.world.toScreenPos(self.player.position).add(PLAYER_SIZE.scale(-0.5)),
            .size = PLAYER_SIZE,
            .color = colors.solarized_red,
        });
        if (self.player.actor.carrying) |_| {
            self.haathi.drawRect(.{
                .position = self.world.toScreenPos(self.player.position).add(PLAYER_SIZE.scale(-0.5)).add(PLAYER_SIZE.yVec()).add(PLAYER_SIZE.xVec().scale(0.5)).add(.{ .x = -6, .y = -6 }),
                .size = .{ .x = 12, .y = 12 },
                .color = colors.solarized_orange,
            });
        }
        self.haathi.drawText(.{
            .text = "you",
            .position = self.world.toScreenPos(self.player.position).add(PLAYER_SIZE.scale(0.0)),
            .color = colors.solarized_base03,
        });
        if (self.mode == .day) {
            // enerrgy
            self.haathi.drawText(.{ .text = "Energy:", .position = .{ .x = 60, .y = 14 }, .color = colors.solarized_base03 });
            const start = Vec2{ .x = 122, .y = 20 };
            const end = Vec2{ .x = SCREEN_SIZE.x - (GRID_CELL_SIZE.x * 4) - 2, .y = 20 };
            self.haathi.drawLine(.{ .p0 = start.add(.{ .x = -2 }), .p1 = end.add(.{ .x = 2 }), .width = 25, .color = colors.solarized_base03 });
            const energy: f32 = @as(f32, @floatFromInt(self.player.actor.energy)) / @as(f32, @floatFromInt(self.player.actor.total_energy));
            self.haathi.drawLine(.{ .p0 = start, .p1 = start.lerp(end, energy), .width = 20, .color = colors.solarized_base3 });
        }
        if (self.mode == .sunrise) {
            if (!self.builder.hide_menu) {
                self.haathi.drawRect(.{
                    .position = .{},
                    .size = SCREEN_SIZE,
                    .color = colors.solarized_base03.lerp(colors.solarized_orange, 0.3).alpha(0.3),
                });
                for (self.menu.items) |item| {
                    switch (item) {
                        .button => |button| {
                            const color = if (button.hovered) colors.solarized_base01.lerp(colors.solarized_base3, 0.4) else colors.solarized_base01;
                            self.haathi.drawRect(.{ .position = button.rect.position, .size = button.rect.size, .color = color, .radius = 4 });
                            const text_center = button.rect.position.add(button.rect.size.scaleVec2(.{ .x = 0.5, .y = 1 }).add(.{ .y = -18 }));
                            self.haathi.drawText(.{ .text = button.text, .position = text_center, .color = colors.solarized_base3 });
                        },
                        .rect => |rect| {
                            self.haathi.drawRect(.{ .position = rect.position, .size = rect.size, .color = colors.solarized_base02, .radius = 4 });
                        },
                        .text => |text| {
                            self.haathi.drawText(.{ .text = text.text, .position = text.position, .color = text.color });
                        },
                    }
                }
            }
            for (self.contextual.items) |item| {
                switch (item) {
                    .button => |button| {
                        const color = if (button.hovered) colors.solarized_base01.lerp(colors.solarized_base3, 0.4) else colors.solarized_base01;
                        self.haathi.drawRect(.{ .position = button.rect.position, .size = button.rect.size, .color = color, .radius = 4 });
                        const text_center = button.rect.position.add(button.rect.size.scaleVec2(.{ .x = 0.5, .y = 1 }).add(.{ .y = -18 }));
                        self.haathi.drawText(.{ .text = button.text, .position = text_center, .color = colors.solarized_base3 });
                    },
                    .rect => |rect| {
                        self.haathi.drawRect(.{ .position = rect.position, .size = rect.size, .color = colors.solarized_base02, .radius = 4 });
                    },
                    .text => |text| {
                        self.haathi.drawText(.{ .text = text.text, .position = text.position, .color = text.color });
                    },
                }
            }
        }

        const inventory = std.fmt.allocPrintZ(self.haathi.arena, "Ore: {d}", .{self.inventory[0]}) catch unreachable;
        self.haathi.drawText(.{ .text = inventory, .position = .{ .x = 60, .y = 50 }, .color = colors.solarized_base03 });
        if (false) { // testing lerp
            const center = Vec2i{};
            const target = center.orthoTarget(mouse_address);
            self.drawCellInset(target, 10, colors.white);
        }
    }
};
