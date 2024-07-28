const std = @import("std");
const c = @import("interface.zig");
const haathi_lib = @import("haathi.zig");
const Haathi = @import("haathi.zig").Haathi;
const colors = @import("colors.zig");
const MouseState = @import("inputs.zig").MouseState;
const SCREEN_SIZE = @import("haathi.zig").SCREEN_SIZE;
const CursorStyle = @import("haathi.zig").CursorStyle;
const serializer = @import("serializer.zig");

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

const LOOP_LIFE_TICKS = 90;
const LOOP_MIN_AREA = 700;
const PLAYER_ACCELERATION = 2;
const PLAYER_VELOCITY_MAX = 6;
const PLAYER_VELOCITY_MAX_SQR = PLAYER_VELOCITY_MAX * PLAYER_VELOCITY_MAX;
const PLAYER_VELOCITY_DAMPING = 0.2;
const PLAYER_SIZE = Vec2{ .x = 20, .y = 30 };
const PLAYER_LIGHT_RADIUS = 45;
const LAMP_LIGHT_RADIUS = 60;
const PLAYER_LIGHT_RADIUS_SQR = PLAYER_LIGHT_RADIUS * PLAYER_LIGHT_RADIUS;
const PLAYER_LIGHT_SIZE = Vec2{ .x = PLAYER_LIGHT_RADIUS * 2, .y = PLAYER_LIGHT_RADIUS * 2 };
const PLAYER_ACT_RANGE = 2;
const SPIRIT_LIGHT_RADIUS = 25;
const SPIRIT_LIGHT_RADIUS_SQR = SPIRIT_LIGHT_RADIUS * SPIRIT_LIGHT_RADIUS;
const SPIRIT_LIGHT_SIZE = Vec2{ .x = SPIRIT_LIGHT_RADIUS * 2, .y = SPIRIT_LIGHT_RADIUS * 2 };
const SPIRIT_SIZE = Vec2{ .x = 10, .y = 10 };
const DJINN_SIZE = Vec2{ .x = 16, .y = 22 };
const GRID_SIZE = Vec2i{ .x = 50, .y = 24 };
const WORLD_SIZE = SCREEN_SIZE.subtract(.{ .x = 54, .y = 132 });
const WORLD_OFFSET = Vec2{ .x = 28, .y = 100 };
const GRID_CELL_SIZE = Vec2{
    .x = WORLD_SIZE.x / @as(f32, @floatFromInt(GRID_SIZE.x)),
    .y = WORLD_SIZE.y / @as(f32, @floatFromInt(GRID_SIZE.y)),
};
const OFF_SCREEN_POS = .{ .x = 2000, .y = 2000 };
const GRID_OFFSET = GRID_SIZE.divide(2);
const SHADOW_SCARED_TICKS = 120;
const SHADOW_DECELERATE_RATE = 0.95;
const LAMP_RESET_TICKS = 30;
const LOOP_KILL_TICKS = 60;
const ENERGY_DEFAULT_VALUE = 10;
const FF_STEPS = 300;
const EXTRA_FF_STEPS = 1000;
const NIGHT_TICKS = 60 * 60;
const RESOURCE_ANIMATION_TICKS = DJINN_TICK_COUNT;

const COST_OF_MINE = 5;
const COST_OF_TRAP = 3;
const COST_OF_LAMP = 2;
const COST_OF_COMBINER = 10;
const START_COST_OF_DJINN = 1;
const START_GEMS = COST_OF_MINE;
const TRAIL_SEGMENT_LEN = 15;
const TRAIL_SEGMENT_LEN_SQR = TRAIL_SEGMENT_LEN * TRAIL_SEGMENT_LEN;
const TRAIL_TOTAL_LEN = TRAIL_SEGMENT_LEN * 30;
const TRAIL_TOTAL_LEN_SQR = TRAIL_TOTAL_LEN * TRAIL_TOTAL_LEN;

const DJINN_TICK_COUNT = 15;
const build_options = @import("build_options");
const BUILDER_MODE = build_options.builder_mode;
const ORE_START_OFFSET = Vec2{ .x = 1, .y = 22 };
const ORE_ANIMATION_OFFSETS = [4]f32{ 0, -1, 2, 4 };

const ORE_SPRITES = [_]haathi_lib.Sprite{
    .{ .path = "/img/ore0.png", .anchor = .{}, .size = .{ .x = 18, .y = 20 } },
    .{ .path = "/img/ore0.png", .anchor = .{}, .size = .{ .x = 18, .y = 20 } },
    .{ .path = "/img/ore1.png", .anchor = .{}, .size = .{ .x = 18, .y = 20 } },
};

// TODO (23 Jul 2024 sam): lol
const NUMBER_STR = [_][]const u8{ "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15", "16", "17", "18", "19", "20", "21", "22", "23", "24", "25", "26", "27", "28", "29", "30", "31", "32", "33", "34", "35", "36", "37", "38", "39", "40", "41", "42", "43", "44", "45", "46", "47", "48", "49" };

const OrePatch = struct {
    position: Vec2i,
};

// World has origin at the center, x-right, y-up.
// Screen has origin at bottomleft, x-right, y-up
const World = struct {
    size: Vec2 = WORLD_SIZE,
    offset: Vec2 = WORLD_OFFSET,
    center: Vec2 = WORLD_OFFSET.add(WORLD_SIZE.scale(0.5)),
    cell_origin: Vec2i = .{ .x = GRID_SIZE.x / -2, .y = GRID_SIZE.y / -2 },
    ore_patches: std.ArrayList(OrePatch),

    pub fn init(allocator: std.mem.Allocator) World {
        helpers.debugPrint("size = {d}", .{GRID_CELL_SIZE.x});
        return .{
            .ore_patches = std.ArrayList(OrePatch).init(allocator),
        };
    }

    pub fn setup(self: *World) void {
        const ORE_POSITIONS = [_]Vec2i{
            .{ .x = 6, .y = 3 },
            .{ .x = 6, .y = -4 },
        };
        for (ORE_POSITIONS) |op| self.ore_patches.append(.{ .position = op }) catch unreachable;
    }

    pub fn deinit(self: *World) void {
        self.ore_patches.deinit();
    }

    pub fn clear(self: *World) void {
        self.ore_patches.clearRetainingCapacity();
        self.center = WORLD_OFFSET.add(WORLD_SIZE.scale(0.5));
    }

    pub fn worldToScreen(self: *const World, position: Vec2) Vec2 {
        return position.add(self.center);
    }

    pub fn screenToWorld(self: *const World, position: Vec2) Vec2 {
        return position.subtract(self.center);
    }

    pub fn worldPosToAddress(self: *const World, position: Vec2) Vec2i {
        const pos = position;
        const x = pos.x / GRID_CELL_SIZE.x;
        const y = pos.y / GRID_CELL_SIZE.y;
        const cell = Vec2{ .x = x, .y = y };
        return self.clampAddress(cell.floorI());
    }

    pub fn clampAddress(self: *const World, address: Vec2i) Vec2i {
        var cell = address;
        cell.x = std.math.clamp(cell.x, self.cell_origin.x, self.cell_origin.x + GRID_SIZE.x - 1);
        cell.y = std.math.clamp(cell.y, self.cell_origin.y, self.cell_origin.y + GRID_SIZE.y - 1);
        return cell;
    }

    // Returned rect is in world space.
    pub fn cellToRect(self: *const World, cell: Vec2i) Rect {
        //const pos = cell.add(GRID_OFFSET);
        _ = self;
        const pos = cell;
        const xpos = (@as(f32, @floatFromInt(pos.x)) * GRID_CELL_SIZE.x);
        const ypos = (@as(f32, @floatFromInt(pos.y)) * GRID_CELL_SIZE.y);
        return .{ .position = .{ .x = xpos, .y = ypos }, .size = GRID_CELL_SIZE };
    }

    pub fn gridCenter(self: *const World, cell: Vec2i) Vec2 {
        return self.cellToRect(cell).center();
    }

    pub fn gridCenterScreen(self: *const World, cell: Vec2i) Vec2 {
        return self.worldToScreen(self.cellToRect(cell).center());
    }

    pub fn maxX(self: *const World) f32 {
        _ = self;
        return GRID_CELL_SIZE.x * @as(f32, @floatFromInt(GRID_SIZE.x / 2));
    }
    pub fn maxY(self: *const World) f32 {
        _ = self;
        return GRID_CELL_SIZE.y * @as(f32, @floatFromInt(GRID_SIZE.y / 2));
    }
    pub fn minX(self: *const World) f32 {
        _ = self;
        return GRID_CELL_SIZE.x * @as(f32, @floatFromInt(-GRID_SIZE.x / 2));
    }
    pub fn minY(self: *const World) f32 {
        _ = self;
        return GRID_CELL_SIZE.y * @as(f32, @floatFromInt(-GRID_SIZE.y / 2));
    }

    pub fn clampInWorldBounds(self: *const World, position: Vec2) Vec2 {
        var clamped = position;
        clamped.x = @min(clamped.x, self.maxX());
        clamped.y = @min(clamped.y, self.maxY());
        clamped.x = @max(clamped.x, self.minX());
        clamped.y = @max(clamped.y, self.minY());
        return clamped;
    }
};

const Trail = struct {
    points: std.ArrayList(Vec2),
    length: f32 = 0,
    intersection: ?Vec2 = null,
    intersection_index: usize = 0,

    pub fn init(allocator: std.mem.Allocator) Trail {
        return .{ .points = std.ArrayList(Vec2).init(allocator) };
    }

    pub fn deinit(self: *Trail) void {
        self.points.deinit();
    }

    pub fn reset(self: *Trail) void {
        self.points.clearRetainingCapacity();
        self.length = 0;
        self.intersection = null;
    }

    pub fn beginTrail(self: *Trail, position: Vec2) void {
        self.reset();
        self.points.append(position) catch unreachable;
    }

    pub fn endTrail(self: *Trail, position: Vec2) void {
        if (self.points.items.len == 0) return;
        const prev = self.points.getLast();
        const dist = prev.distanceSqr(position);
        self.length += @sqrt(dist);
        self.points.append(position) catch unreachable;
    }

    pub fn intersects(self: *const Trail, p0: Vec2, p1: Vec2, int_index: *usize) ?Vec2 {
        const len = self.points.items.len;
        if (len <= 2) return null;
        for (self.points.items[0 .. len - 2], self.points.items[1 .. len - 1], 0..) |q0, q1, i| {
            if (helpers.lineSegmentsIntersect(p0, p1, q0, q1)) |point| {
                int_index.* = i + 1;
                return point;
            }
        }
        return null;
    }

    pub fn inRange(self: *const Trail, p0: Vec2, p1: Vec2, range: f32) ?Vec2 {
        _ = p0;
        const len = self.points.items.len;
        if (len == 0) return null;
        const range_sqr = range * range;
        for (self.points.items[0 .. len - 1], self.points.items[1..len]) |q0, q1| {
            if (helpers.pointToLineDistanceSqr(p1, q0, q1) < range_sqr) {
                return q0.lerp(q1, 0.5);
            }
        }
        return null;
    }

    pub fn update(self: *Trail, position: Vec2) void {
        if (self.intersection != null) return;
        if (self.points.items.len == 0) return;
        const prev = self.points.getLast();
        const dist = prev.distanceSqr(position);
        if (dist > TRAIL_SEGMENT_LEN_SQR) {
            if (self.intersects(position, prev, &self.intersection_index)) |point| {
                self.intersection = point;
                self.points.append(point) catch unreachable;
                return;
            }
            self.points.append(position) catch unreachable;
            self.length += @sqrt(dist);
        }
        if (self.length > TRAIL_TOTAL_LEN) {
            helpers.assert(self.points.items.len > 2);
            const old_first = self.points.orderedRemove(0);
            const new_first = self.points.items[0];
            const to_sub = old_first.distanceSqr(new_first);
            self.length -= @sqrt(to_sub);
        }
    }
};

const Player = struct {
    position: Vec2 = .{},
    velocity: Vec2 = .{},
    address: Vec2i = .{},
    action_available: ?Action = null,
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

    pub fn updatePosition(self: *Player, game: *const Game) void {
        const old_pos = self.position;
        self.position = self.position.add(self.velocity);
        self.position = game.world.clampInWorldBounds(self.position);
        self.position = self.position.round();
        self.position = game.structureCollision(old_pos, self.position) orelse self.position;
        self.address = game.world.worldPosToAddress(self.position);
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
            .action => true,
            .dropoff, .pickup => false,
        };
    }
};

const Destroyable = struct {
    item: enum { structure, shadow },
    position: Vec2,
};

pub const StructureType = enum {
    base,
    mine,
    altar,
    lamp,
    combiner,

    pub fn startingHealth(self: *const StructureType) u16 {
        return switch (self.*) {
            .base => 500,
            .mine => 50,
            .altar => 10,
            .lamp => 10,
            .combiner => 50,
        };
    }
};

pub const Structure = struct {
    structure: StructureType,
    position: Vec2 = .{},
    address: Vec2i = .{},
    orientation: Orientation = .n,
    shadow: ?ShadowIndex = null,
    count: usize = 0,
    health: u16 = 4,
    slots: [4]?SlotType = [_]?SlotType{null} ** 4,

    fn setup(self: *Structure, world: World) void {
        self.health = self.structure.startingHealth();
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
            .altar => {
                self.position = world.gridCenter(self.address);
            },
            .combiner => {
                self.slots[self.orientation.toIndex()] = .pickup;
                self.slots[self.orientation.next().toIndex()] = .action;
                self.slots[self.orientation.opposite().toIndex()] = .dropoff;
                self.slots[self.orientation.opposite().next().toIndex()] = .dropoff;
            },
            .lamp => {
                self.slots[self.orientation.toIndex()] = .pickup;
                self.slots[self.orientation.next().toIndex()] = .action;
            },
        }
    }

    pub fn update(self: *Structure, game: *Game) void {
        if (self.structure == .altar) {
            if (self.count > 0) self.count -= 1;
            if (self.count == 0 and self.shadow != null) {
                game.shadows.shadows.getPtr(self.shadow.?).dead = true;
                self.shadow = null;
            }
        }
    }
};

const ResourceType = enum {
    lead,
    tin,
    iron,

    pub fn value(self: *const ResourceType) u8 {
        return @as(u8, @intFromEnum(self.*)) + 1;
    }

    pub fn fromValue(val: u8) ResourceType {
        helpers.assert(val > 0);
        return @enumFromInt(val - 1);
    }
};
const RESOURCE_COUNT = @typeInfo(ResourceType).Enum.fields.len;

const Resource = struct {
    address: Vec2i,
    resource: ResourceType,
    start_pos: Vec2,
    end_pos: Vec2,
    start_scale: f32,
    end_scale: f32,
    progress: usize = 0,
    position: Vec2,
    scale: f32,

    pub fn create(rsc: ResourceType, start: Vec2i, end: Vec2i, created: bool, world: World) Resource {
        return .{
            .resource = rsc,
            .address = end,
            .start_pos = world.gridCenter(start),
            .end_pos = world.gridCenter(end),
            .start_scale = if (created) 0 else 1,
            .end_scale = if (created) 1 else 0,
            .position = world.gridCenter(start),
            .scale = if (created) 0 else 1,
        };
    }

    pub fn update(self: *Resource) void {
        self.progress += 1;
        if (self.progress > RESOURCE_ANIMATION_TICKS) return;
        const t: f32 = @as(f32, @floatFromInt(self.progress)) / RESOURCE_ANIMATION_TICKS;
        self.position = self.start_pos.lerp(self.end_pos, t);
        self.scale = helpers.lerpf(self.start_scale, self.end_scale, t);
    }
};

const Lamp = struct {
    address: Vec2i,
    position: Vec2,
    radius: f32 = LAMP_LIGHT_RADIUS,
    progress: u32 = 0,
    target: ?ShadowIndex = null,
    target_countdown: usize = 0,

    pub fn create(address: Vec2i, world: World) Lamp {
        return .{ .address = address, .position = world.screenToWorld(world.gridCenter(address)) };
    }

    pub fn update(self: *Lamp) void {
        if (self.target_countdown > 0) {
            self.target_countdown -= 1;
        } else {
            self.target = null;
        }
    }
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
        if (self.points.items.len == 0) return null;
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
    loop_create,
    loop_delete,
    djinn_manage,
    build,

    pub fn hidesMenu(self: *const BuilderMode) bool {
        return switch (self.*) {
            .menu => false,
            .loop_create,
            .loop_delete,
            .djinn_manage,
            .build,
            => true,
        };
    }
};

pub const Builder = struct {
    mode: BuilderMode = .menu,
    structure: StructureType = undefined,
    position: Vec2i = .{},
    orientation: Orientation = .n,
    current_path: Path,
    target: Vec2i = .{},
    invalid: ?Vec2i = null,
    can_build: bool = false,
    hide_menu: bool = false,
    open: bool = true,

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
    should_move: bool,
};

pub const Actor = struct {
    carrying: ?ResourceType = null,
    energy: u8 = ENERGY_DEFAULT_VALUE,
    total_energy: u8 = ENERGY_DEFAULT_VALUE,
};

pub const Djinn = struct {
    position: Vec2,
    address: Vec2i = undefined,
    path: ?PathIndex = null,
    cell_index: usize = undefined,
    target_address: Vec2i = .{},
    anim_start_pos: Vec2 = .{},
    anim_end_pos: Vec2 = .{},
    actor: Actor = .{},

    pub fn update(self: *Djinn, game: *Game, ds: *DjinnSystem) void {
        if (self.path == null) {
            self.position = OFF_SCREEN_POS;
            return;
        }
        var should_move = true;
        if (game.actionAvailable(self.target_address, self.actor)) |action| {
            if (!action.can_be_done and action.blocking) {
                // if the djinn is carrying something when 0 energy, should not block
                if (!action.should_move) should_move = false;
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
            ds.moved = true;
        }
        if (self.cell_index == path.cells.items.len) self.cell_index = 0;
        self.target_address = path.cells.items[self.cell_index];
        self.anim_end_pos = game.world.gridCenter(self.target_address);
    }

    pub fn lerpPosition(self: *Djinn, t: f32) void {
        if (self.path == null) {
            self.position = OFF_SCREEN_POS;
            return;
        }
        self.position = self.anim_start_pos.lerp(self.anim_end_pos, t);
    }

    pub fn movingLeft(self: *const Djinn) bool {
        return self.anim_end_pos.x < self.anim_start_pos.x;
    }
};

pub const DjinnSystem = struct {
    djinns: ConstIndexArray(DjinnIndex, Djinn),
    ticks: usize = 0,
    ff_steps: usize = 0,
    // TODO (24 Jul 2024 sam): This is to deal with some stuck scenario
    moved: bool = false,

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

    pub fn addDjinn(self: *DjinnSystem) void {
        self.djinns.append(.{ .position = OFF_SCREEN_POS }) catch unreachable;
    }

    pub fn pathCount(self: *DjinnSystem, pkey: PathIndex) usize {
        var count: usize = 0;
        for (self.djinns.items()) |djinn| {
            if (djinn.path != null and djinn.path.?.equal(pkey)) count += 1;
        }
        return count;
    }

    pub fn energyRemaining(self: *DjinnSystem) bool {
        for (self.djinns.items()) |djinn| {
            if (djinn.actor.energy > 0 or djinn.actor.carrying != null) return true;
        }
        return false;
    }

    pub fn resetEnergy(self: *DjinnSystem) void {
        for (self.djinns.items()) |*djinn| {
            djinn.actor.energy = djinn.actor.total_energy;
        }
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
                djinn.position = OFF_SCREEN_POS;
                return;
            }
        }
    }

    pub fn availableDjinnCount(self: *DjinnSystem) usize {
        var count: usize = 0;
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
                djinn.position = OFF_SCREEN_POS;
            }
        }
    }

    pub fn update(self: *DjinnSystem, game: *Game) void {
        self.moved = false;
        defer self.ticks += 1;
        if (self.ticks % DJINN_TICK_COUNT == 0) {
            for (self.djinns.items()) |*djinn| {
                djinn.update(game, self);
            }
        }
        const t: f32 = @as(f32, @floatFromInt(self.ticks % DJINN_TICK_COUNT)) / DJINN_TICK_COUNT;
        for (self.djinns.items()) |*djinn| djinn.lerpPosition(t);
    }
};

pub const ShadowType = enum {
    normal,
    fast,
    strong,

    pub fn velocityMax(self: *const ShadowType) f32 {
        return switch (self.*) {
            .normal => 1.5,
            .fast => 4,
            .strong => 0.8,
        };
    }

    pub fn size(self: *const ShadowType) Vec2 {
        return switch (self.*) {
            .normal => .{ .x = 16, .y = 22 },
            .fast => .{ .x = 10, .y = 18 },
            .strong => .{ .x = 22, .y = 30 },
        };
    }

    pub fn radius(self: *const ShadowType) f32 {
        return self.size().y;
    }

    pub fn damage(self: *const ShadowType) u16 {
        return switch (self.*) {
            .normal => 10,
            .fast => 2,
            .strong => 30,
        };
    }

    pub fn velocityScared(self: *const ShadowType) f32 {
        return self.velocityMax() * 2;
    }

    pub fn color(self: *const ShadowType) Vec4 {
        return switch (self.*) {
            .normal => colors.solarized_cyan,
            .fast => colors.solarized_cyan.lerp(colors.solarized_blue, 0.4),
            .strong => colors.solarized_cyan.lerp(colors.solarized_green, 0.4),
        };
    }
};

pub const Shadow = struct {
    shadow: ShadowType = .normal,
    position: Vec2,
    velocity: Vec2 = .{},
    vel_mag: f32,
    radius: f32,
    dead: bool = false,
    death_count: ?u16 = null,

    pub fn init(position: Vec2, rng: std.rand.Random, stype: ?ShadowType) Shadow {
        const shadow = stype orelse rng.enumValue(ShadowType);
        const vel_mag = shadow.velocityMax();
        const vel = (Vec2{ .x = (rng.float(f32) * 2) - 1, .y = (rng.float(f32) * 2) - 1 }).normalize().scale(vel_mag);
        return .{
            .shadow = shadow,
            .position = position,
            .velocity = vel,
            .vel_mag = vel_mag,
            .radius = shadow.radius(),
        };
    }

    // returns if the direction  was changed
    pub fn update(self: *Shadow, game: *Game) bool {
        if (self.death_count) |dc| {
            if (dc == 0) {
                self.dead = true;
                return false;
            } else {
                self.death_count = dc - 1;
            }
            return false;
        }
        var dir_changed = false;
        const old_v = self.vel_mag;
        self.vel_mag = @max(self.shadow.velocityMax(), self.vel_mag * SHADOW_DECELERATE_RATE);
        if (old_v != self.vel_mag) self.velocity = self.velocity.normalize().scale(self.vel_mag);
        const new_position = self.position.add(self.velocity);
        if (game.getWorldRepeller(self.position, new_position, self.radius)) |repeller| {
            self.velocity = self.position.subtract(repeller).normalize().scale(self.vel_mag);
            dir_changed = true;
        } else if (game.collides(self.position, new_position, self.shadow)) |center| {
            self.velocity = self.position.subtract(center).normalize().scale(self.vel_mag);
            dir_changed = true;
        } else if (game.inPlayerRange(self.position, new_position, self.radius)) |center| {
            self.vel_mag = self.shadow.velocityScared();
            self.velocity = self.position.subtract(center).normalize().scale(self.vel_mag);
            self.position = new_position;
            dir_changed = true;
        } else {
            self.position = new_position;
        }
        return dir_changed;
    }

    pub fn markDead(self: *Shadow) void {
        self.vel_mag = 0;
        self.velocity = .{};
        self.death_count = LOOP_KILL_TICKS;
    }
};

pub const ShadowSystem = struct {
    shadows: ConstIndexArray(ShadowIndex, Shadow),
    changed: std.ArrayList(ShadowIndex),

    pub fn init(allocator: std.mem.Allocator) ShadowSystem {
        return .{
            .shadows = ConstIndexArray(ShadowIndex, Shadow).init(allocator),
            .changed = std.ArrayList(ShadowIndex).init(allocator),
        };
    }

    pub fn deinit(self: *ShadowSystem) void {
        self.shadows.deinit();
        self.changed.deinit();
    }

    pub fn clear(self: *ShadowSystem) void {
        self.shadows.clearRetainingCapacity();
        self.changed.clearRetainingCapacity();
    }

    pub fn reset(self: *ShadowSystem) void {
        self.clear();
    }

    pub fn addShadow(self: *ShadowSystem, position: Vec2, rng: std.Random) void {
        const shadow = Shadow.init(position, rng, null);
        self.shadows.append(shadow) catch unreachable;
    }

    pub fn allDead(self: *const ShadowSystem) bool {
        for (self.shadows.constItems()) |shadow| {
            if (!shadow.dead) return false;
        }
        return true;
    }

    pub fn update(self: *ShadowSystem, game: *Game) void {
        self.changed.clearRetainingCapacity();
        for (self.shadows.keys()) |skey| {
            const shadow = self.shadows.getPtr(skey);
            const vel_changed = shadow.update(game);
            if (vel_changed) self.changed.append(skey) catch unreachable;
        }
    }
};

pub const GameMode = enum {
    new_game,
    sunrise,
    day,
    sunset,
    night,
    lost,

    pub fn shouldShowStats(self: *const GameMode) bool {
        return switch (self.*) {
            .sunrise,
            .day,
            .sunset,
            => true,
            .new_game,
            .night,
            .lost,
            => false,
        };
    }
};

// magical things that the shadows are trying to steal.
pub const Spirit = struct {
    position: Vec2,
    shadow: ?ShadowIndex = null,
};

const MenuAction = enum {
    none,
    set_mode_build_mine,
    set_mode_build_altar,
    set_mode_build_lamp,
    set_mode_build_combiner,
    set_mode_loop_create,
    set_mode_loop_delete,
    set_mode_djinn_manage,
    action_loop_delete,
    action_djinn_remove,
    action_djinn_add,
    action_start_game,
    action_start_day,
    action_start_night,
    action_ff_to_sunset,
    action_summon_djinn,
    hide_menu,
};

const MenuText = struct {
    position: Vec2,
    text: []const u8,
    color: Vec4,
    font: []const u8 = FONTS[0],
    alignment: haathi_lib.TextAlignment = .left,
};

const MenuItem = union(enum) {
    rect: Rect,
    button: Button,
    text: MenuText,
};

const Loop = struct {
    points: std.ArrayList(Vec2),
    life: u16 = LOOP_LIFE_TICKS,
    center: Vec2,
    destroyed: std.ArrayList(Destroyable),

    pub fn init(allocator: std.mem.Allocator, points_in: []Vec2, destroyed: []Destroyable) Loop {
        var points = std.ArrayList(Vec2).initCapacity(allocator, points_in.len) catch unreachable;
        points.appendSlice(points_in) catch unreachable;
        var center = Vec2{};
        for (points_in) |pt| center = center.add(pt);
        center = center.scale(1 / @as(f32, @floatFromInt(points_in.len)));
        var dest = std.ArrayList(Destroyable).initCapacity(allocator, destroyed.len) catch unreachable;
        dest.appendSlice(destroyed) catch unreachable;
        return .{ .points = points, .destroyed = dest, .center = center };
    }

    pub fn deinit(self: *Loop) void {
        self.points.deinit();
    }

    pub fn update(self: *Loop) void {
        if (self.life > 0) self.life -= 1;
    }
};

const Alert = struct {
    target: StructureIndex,
    target_pos: Vec2,
    shadow: ShadowIndex,
    predicted_steps: f32,

    fn earlier(_: void, alert1: Alert, alert2: Alert) bool {
        return alert1.predicted_steps < alert2.predicted_steps;
    }
};

const AlertSystem = struct {
    alerts: std.ArrayList(Alert),
    timer: u64 = 0,
    last: u64 = 0,
    per_second: f32 = 0,

    pub fn init(allocator: std.mem.Allocator) AlertSystem {
        return .{
            .alerts = std.ArrayList(Alert).init(allocator),
        };
    }

    pub fn deinit(self: *AlertSystem) void {
        self.alerts.deinit();
    }

    pub fn clear(self: *AlertSystem) void {
        self.alerts.clearRetainingCapacity();
        self.timer = 0;
        self.last = 0;
    }

    pub fn update(self: *AlertSystem, game: *Game) void {
        // remove if it already exists (means dir changed, so its no longer hitting)
        for (game.shadows.changed.items) |skey| {
            for (self.alerts.items, 0..) |alert, i| {
                if (alert.shadow.equal(skey)) {
                    _ = self.alerts.swapRemove(i);
                    break;
                }
            }
        }
        for (game.shadows.changed.items) |skey| {
            const shadow = game.shadows.shadows.getPtr(skey);
            const pos = shadow.position;
            if (game.hitsStructure(pos, shadow.velocity, skey)) |alert| {
                self.alerts.append(alert) catch unreachable;
            }
        }
        // Remove alerts if it has already hit or dead
        var to_remove = std.ArrayList(usize).init(game.haathi.arena);
        for (self.alerts.items, 0..) |*alert, i| {
            alert.predicted_steps -= 1;
            const shadow = game.shadows.shadows.getPtr(alert.shadow);
            if (shadow.dead) to_remove.insert(0, i) catch unreachable;
        }
        for (to_remove.items) |i| _ = self.alerts.swapRemove(i);
        if (self.alerts.items.len == 0) {
            self.per_second = 0;
            return;
        }
        std.sort.pdq(Alert, self.alerts.items, {}, Alert.earlier);
        const alert = self.alerts.items[0];
        const MAX_ALERTS_PER_SECOND = 8;
        const ALERT_TIMELINE_MAX = 4;
        const ALERT_TIMELINE_MIN = 0.2;
        if (alert.predicted_steps > ALERT_TIMELINE_MAX * 60) {
            self.per_second = 0;
            return;
        }
        const prog = helpers.unlerpf(ALERT_TIMELINE_MAX, ALERT_TIMELINE_MIN, alert.predicted_steps / 60);
        self.per_second = helpers.lerpf(0, MAX_ALERTS_PER_SECOND, prog);
        //helpers.debugPrint("prog = {d}, per_second={d}", .{ prog, self.per_second });
    }

    pub fn play(self: *AlertSystem, game: *Game) void {
        self.timer += 1;
        if (self.per_second == 0) return;
        const num_ticks = self.timer - self.last;
        const seconds_passed = @as(f32, @floatFromInt(num_ticks)) / 60;
        const reqd_passed = 1 / self.per_second;
        if (seconds_passed > reqd_passed) {
            game.haathi.playSound("audio/danger.wav", true);
            self.last = self.timer;
        }
    }
};

// gameStruct
pub const Game = struct {
    haathi: *Haathi,
    ticks: u64 = 0,
    world: World,
    resources: std.ArrayList(Resource),
    structures: ConstIndexArray(StructureIndex, Structure),
    paths: ConstIndexArray(PathIndex, Path),
    spirits: ConstIndexArray(SpiritIndex, Spirit),
    lamps: std.ArrayList(Lamp),
    loops: std.ArrayList(Loop),
    alerts: AlertSystem,
    inventory: [RESOURCE_COUNT]u16 = [_]u16{0} ** RESOURCE_COUNT,
    djinns: DjinnSystem,
    shadows: ShadowSystem,
    player: Player = .{},
    trail: Trail,
    builder: Builder,
    xosh: std.Random.Xoshiro256,
    rng: std.Random = undefined,
    mode: GameMode = .sunrise,
    stone_index: SpiritIndex = undefined,
    ff_mode: if (BUILDER_MODE) bool else void = if (BUILDER_MODE) false else {},
    ff_to_sunset: bool = false,
    menu: std.ArrayList(MenuItem),
    contextual: std.ArrayList(MenuItem),
    day_count: u16 = 0,
    gems: usize = 0,
    steps: usize = 0,
    djinn_summon_cost: u32 = START_COST_OF_DJINN,

    allocator: std.mem.Allocator,
    arena_handle: std.heap.ArenaAllocator,
    arena: std.mem.Allocator,

    pub const serialize_fields = [_][]const u8{ "ticks", "steps", "world", "resources", "structures", "paths", "spirits", "inventory", "djinns", "shadows", "player", "builder", "mode", "stone_index", "ff_mode", "ff_to_sunset", "menu", "contextual", "day_count", "gems", "djinn_summon_cost", "lamps", "trail", "alerts" };

    pub fn init(haathi: *Haathi) Game {
        haathi.loadSound("audio/damage.wav", false);
        haathi.loadSound("audio/danger.wav", false);
        haathi.loadSound("audio/capture.wav", false);
        const allocator = haathi.allocator;
        var arena_handle = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        const world = World.init(haathi.allocator);
        return .{
            .haathi = haathi,
            .structures = ConstIndexArray(StructureIndex, Structure).init(allocator),
            .lamps = std.ArrayList(Lamp).init(allocator),
            .resources = std.ArrayList(Resource).init(allocator),
            .loops = std.ArrayList(Loop).init(allocator),
            .paths = ConstIndexArray(PathIndex, Path).init(allocator),
            .spirits = ConstIndexArray(SpiritIndex, Spirit).init(allocator),
            .builder = Builder.init(allocator),
            .alerts = AlertSystem.init(allocator),
            .djinns = DjinnSystem.init(allocator),
            .shadows = ShadowSystem.init(allocator),
            .trail = Trail.init(allocator),
            .xosh = std.Random.Xoshiro256.init(0),
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
        self.lamps.deinit();
        self.structures.deinit();
        self.resources.deinit();
        self.alerts.deinit();
        self.trail.deinit();
        self.spirits.deinit();
        for (self.paths.items()) |*path| path.deinit();
        self.paths.deinit();
        self.world.deinit();
        self.menu.deinit();
        self.contextual.deinit();
        for (self.loops.items) |*loop| loop.deinit();
        self.loops.deinit();
    }

    fn clear(self: *Game) void {
        self.builder.reset();
        self.djinns.reset();
        self.shadows.reset();
        self.structures.clearRetainingCapacity();
        self.trail.reset();
        self.resources.clearRetainingCapacity();
        self.spirits.clearRetainingCapacity();
        for (self.paths.items()) |*path| path.deinit();
        self.paths.clearRetainingCapacity();
        for (self.loops.items) |*loop| loop.deinit();
        self.loops.clearRetainingCapacity();
        self.alerts.clear();
        self.lamps.clearRetainingCapacity();
        self.world.clear();
        self.menu.clearRetainingCapacity();
        self.contextual.clearRetainingCapacity();
        self.inventory = [_]u16{0} ** RESOURCE_COUNT;
    }

    fn reset(self: *Game) void {
        self.clear();
        self.setup();
    }

    pub fn setup(self: *Game) void {
        self.rng = self.xosh.random();
        self.mode = .new_game;
        self.day_count = 0;
        self.gems = START_GEMS;
        self.djinn_summon_cost = START_COST_OF_DJINN;
        self.structures.append(.{ .structure = .base, .address = .{} }) catch unreachable;
        self.world.setup();
        {
            self.stone_index = self.spirits.getNextKey();
            self.spirits.append(.{ .position = .{ .x = 0 } }) catch unreachable;
        }
        self.setupContextual();
        for (self.structures.items()) |*str| str.setup(self.world);
        self.setupNewGameMenu();
    }

    fn addShadows(self: *Game, count: usize) void {
        self.shadows.clear();
        for (0..count) |_| {
            const pos = Vec2{
                .x = (self.rng.float(f32) - 0.5) * WORLD_SIZE.x,
                .y = (self.rng.float(f32) - 0.5) * WORLD_SIZE.y,
            };
            self.shadows.addShadow(pos, self.rng);
        }
    }

    pub fn getWorldRepeller(self: *Game, prev_pos: Vec2, pos: Vec2, radius: f32) ?Vec2 {
        _ = radius;
        if (pos.y > self.world.maxY()) return .{
            .x = helpers.lerpf(prev_pos.x, pos.x, -1),
            .y = self.world.maxY(),
        };
        if (pos.x > self.world.maxX()) return .{
            .x = self.world.maxX(),
            .y = helpers.lerpf(prev_pos.y, pos.y, -1),
        };
        if (pos.y < self.world.minY()) return .{
            .x = helpers.lerpf(prev_pos.x, pos.x, -1),
            .y = self.world.minY(),
        };
        if (pos.x < self.world.minX()) return .{
            .x = self.world.minX(),
            .y = helpers.lerpf(prev_pos.y, pos.y, -1),
        };
        return null;
    }

    pub fn inPlayerRange(self: *Game, prev_pos: Vec2, pos: Vec2, radius: f32) ?Vec2 {
        _ = prev_pos;
        if (pos.distanceSqr(self.player.position) < PLAYER_LIGHT_RADIUS_SQR + radius * radius) {
            return self.player.position;
        }
        return null;
    }

    pub fn damageStructure(self: *Game, skey: StructureIndex, amount: u16) void {
        const structure = self.structures.getPtr(skey);
        if (structure.health > 0) {
            structure.health -= @min(structure.health, amount);
            self.haathi.playSound("audio/damage.wav", false);
        }
    }

    pub fn collides(self: *Game, prev_pos: Vec2, pos: Vec2, shadow_type: ShadowType) ?Vec2 {
        // collide with structure
        const address = self.world.worldPosToAddress(pos);
        for (self.structures.keys()) |skey| {
            const structure = self.structures.getPtr(skey);
            if (structure.address.equal(address)) {
                self.damageStructure(skey, shadow_type.damage());
                return self.world.gridCenter(address);
            }
        }
        if (self.trail.inRange(prev_pos, pos, shadow_type.radius())) |point| return point;
        return null;
    }

    fn setupNewGameMenu(self: *Game) void {
        self.menu.clearRetainingCapacity();
        const sx = SCREEN_SIZE.x;
        const sy = SCREEN_SIZE.y;
        self.menu.append(.{
            .rect = .{
                .position = .{ .x = sx * 0.3, .y = sy * 0.4 },
                .size = .{ .x = sx * 0.4, .y = sy * 0.3 },
            },
        }) catch unreachable;
        var current_pos = Vec2{ .x = sx * 0.3 + 20, .y = sy * 0.7 - 30 };
        self.menu.append(.{
            .text = .{
                .text = "Extract Ore.",
                .position = current_pos,
                .color = colors.solarized_base3,
            },
        }) catch unreachable;
        current_pos = current_pos.add(.{ .y = -40 });
        self.menu.append(.{
            .text = .{
                .text = "Process and Purify till it turns Gold.",
                .position = current_pos,
                .color = colors.solarized_base3,
            },
        }) catch unreachable;
        current_pos = current_pos.add(.{ .y = -40 });
        self.menu.append(.{
            .text = .{
                .text = "WASD to move. Mouse click to do actions.",
                .position = current_pos,
                .color = colors.solarized_base3,
            },
        }) catch unreachable;
        current_pos = current_pos.add(.{ .y = -40 });
        self.menu.append(.{
            .text = .{
                .text = "You'll get the hang of it, I believe in you.",
                .position = current_pos,
                .color = colors.solarized_base3,
            },
        }) catch unreachable;
        current_pos = current_pos.add(.{ .y = -40 });
        self.menu.append(.{
            .button = .{
                .rect = .{
                    .position = current_pos,
                    .size = .{ .x = 200, .y = 25 },
                },
                .value = @intFromEnum(MenuAction.action_start_game),
                .text = "Start Game",
            },
        }) catch unreachable;
    }

    fn setupSunriseMenu(self: *Game, show_start_day_button: bool) void {
        self.menu.clearRetainingCapacity();
        const sx = SCREEN_SIZE.x;
        const sy = SCREEN_SIZE.y;
        self.menu.append(.{
            .rect = .{
                .position = .{ .x = sx * 0.3, .y = sy * 0.4 },
                .size = .{ .x = sx * 0.4, .y = sy * 0.3 },
            },
        }) catch unreachable;
        self.menu.append(.{
            .text = .{
                .text = "You survived the night.",
                .position = .{ .x = sx * 0.5, .y = sy * 0.8 },
                .color = colors.solarized_base03,
            },
        }) catch unreachable;
        var current_pos = Vec2{ .x = sx * 0.3 + 20, .y = sy * 0.7 - 40 };
        self.menu.append(.{
            .button = .{
                .rect = .{
                    .position = current_pos,
                    .size = .{ .x = 200, .y = 25 },
                },
                .value = @intFromEnum(MenuAction.set_mode_build_mine),
                .text = "Build Mine",
                .enabled = self.gems >= self.getMenuActionCost(@intFromEnum(MenuAction.set_mode_build_mine)).?,
            },
        }) catch unreachable;
        if (self.day_count > 0) {
            current_pos = current_pos.add(.{ .y = -40 });
            self.menu.append(.{
                .button = .{
                    .rect = .{
                        .position = current_pos,
                        .size = .{ .x = 200, .y = 25 },
                    },
                    .value = @intFromEnum(MenuAction.set_mode_loop_create),
                    .text = "Create Loop",
                },
            }) catch unreachable;
            current_pos = current_pos.add(.{ .y = -40 });
            self.menu.append(.{
                .button = .{
                    .rect = .{
                        .position = current_pos,
                        .size = .{ .x = 200, .y = 25 },
                    },
                    .value = @intFromEnum(MenuAction.set_mode_loop_delete),
                    .text = "Delete Loop",
                },
            }) catch unreachable;
            current_pos = current_pos.add(.{ .y = -40 });
            self.menu.append(.{
                .button = .{
                    .rect = .{
                        .position = current_pos,
                        .size = .{ .x = 200, .y = 25 },
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
                        .size = .{ .x = 200, .y = 25 },
                    },
                    .value = @intFromEnum(MenuAction.action_summon_djinn),
                    .enabled = self.gems >= self.getMenuActionCost(@intFromEnum(MenuAction.action_summon_djinn)).?,
                    .text = "Summon Djinn",
                },
            }) catch unreachable;
            current_pos = current_pos.add(.{ .y = -40 });
            self.menu.append(.{
                .button = .{
                    .rect = .{
                        .position = current_pos,
                        .size = .{ .x = 200, .y = 25 },
                    },
                    .value = @intFromEnum(MenuAction.set_mode_build_combiner),
                    .enabled = self.gems >= self.getMenuActionCost(@intFromEnum(MenuAction.set_mode_build_combiner)).?,
                    .text = "Build Combiner",
                },
            }) catch unreachable;
        }
        if (show_start_day_button) {
            current_pos = Vec2{ .x = sx * 0.3 + 300, .y = sy * 0.7 - 40 };
            self.menu.append(.{
                .button = .{
                    .rect = .{
                        .position = current_pos,
                        .size = .{ .x = 200, .y = 25 },
                    },
                    .value = @intFromEnum(MenuAction.hide_menu),
                    .text = "View World",
                },
            }) catch unreachable;
            current_pos = current_pos.add(.{ .y = -40 });
            self.menu.append(.{
                .button = .{
                    .rect = .{
                        .position = current_pos,
                        .size = .{ .x = 200, .y = 25 },
                    },
                    .value = @intFromEnum(MenuAction.action_start_day),
                    .text = "Start Day",
                },
            }) catch unreachable;
        }
    }

    fn setupSunsetMenu(self: *Game) void {
        self.menu.clearRetainingCapacity();
        const sx = SCREEN_SIZE.x;
        const sy = SCREEN_SIZE.y;
        self.menu.append(.{
            .text = .{
                .text = "The day has ended.",
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
                    .size = .{ .x = 200, .y = 25 },
                },
                .value = @intFromEnum(MenuAction.set_mode_build_altar),
                .text = "Build Trap",
                .enabled = self.gems >= self.getMenuActionCost(@intFromEnum(MenuAction.set_mode_build_altar)).?,
            },
        }) catch unreachable;
        current_pos = current_pos.add(.{ .y = -40 });
        self.menu.append(.{
            .button = .{
                .rect = .{
                    .position = current_pos,
                    .size = .{ .x = 200, .y = 25 },
                },
                .value = @intFromEnum(MenuAction.set_mode_build_lamp),
                .text = "Build Lamp",
                .enabled = self.gems >= self.getMenuActionCost(@intFromEnum(MenuAction.set_mode_build_lamp)).?,
            },
        }) catch unreachable;
        current_pos = current_pos.add(.{ .y = -40 });
        self.menu.append(.{
            .button = .{
                .rect = .{
                    .position = current_pos,
                    .size = .{ .x = 200, .y = 25 },
                },
                .value = @intFromEnum(MenuAction.action_start_night),
                .text = "Start Night",
            },
        }) catch unreachable;
    }

    fn availableLight(self: *Game, position: Vec2) ?usize {
        for (self.lamps.items, 0..) |lamp, i| {
            if (lamp.target_countdown == 0) {
                if (position.distanceSqr(lamp.position) < (lamp.radius * lamp.radius)) return i;
            }
        }
        return null;
    }

    fn closestSpirit(self: *const Game, position: Vec2) SpiritIndex {
        var closest_spirit: SpiritIndex = undefined;
        var closest_distance_sqr = WORLD_SIZE.x * WORLD_SIZE.x * 1000000;
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
            if (address.distancei(str.address) != 1) continue;
            const slot_orientation = Orientation.getRelative(str.address, address);
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
                        .can_be_done = actor.energy > 0 and has_resource != null and actor.carrying == null,
                        .should_move = true,
                        .blocking = slot.isBlocking(),
                    };
                },
                .dropoff => {
                    if (self.mode == .night) return null;
                    const free = self.hasResource(address) == null;
                    return .{
                        .address = address,
                        .structure = skey,
                        .slot_index = slot_orientation.toIndex(),
                        .can_be_done = is_carrying and free,
                        .should_move = free or !is_carrying,
                        .blocking = is_carrying and !free,
                    };
                },
                .action => {
                    switch (str.structure) {
                        .mine => {
                            // can only do action if there is no resource in the pickup slot
                            if (self.mode == .night) return null;
                            const has_resource = self.hasResource(str.address.add(str.orientation.toDir()));
                            return .{
                                .address = address,
                                .structure = skey,
                                .slot_index = slot_orientation.toIndex(),
                                .can_be_done = has_resource == null and actor.energy > 0,
                                .should_move = has_resource == null or actor.energy == 0,
                                .blocking = slot.isBlocking(),
                            };
                        },
                        .combiner => {
                            // can only do action if there is resources in both the dropoffs, and
                            // no resource in the pickup
                            if (self.mode == .night) return null;
                            const pickup_has_resource = self.hasResource(str.address.add(str.orientation.toDir()));
                            const d0_has_resource = self.hasResource(str.address.add(str.orientation.opposite().toDir()));
                            const d1_has_resource = self.hasResource(str.address.add(str.orientation.opposite().next().toDir()));
                            const resources_correct = pickup_has_resource == null and d0_has_resource != null and d1_has_resource != null;
                            return .{
                                .address = address,
                                .structure = skey,
                                .slot_index = slot_orientation.toIndex(),
                                .can_be_done = resources_correct and actor.energy > 0,
                                .should_move = resources_correct or actor.energy == 0,
                                .blocking = slot.isBlocking(),
                            };
                        },
                        .lamp => {
                            if (self.mode == .day) return null;
                            const pickup_has_lamp = self.hasLamp(str.address.add(str.orientation.toDir()));
                            return .{
                                .address = address,
                                .structure = skey,
                                .slot_index = slot_orientation.toIndex(),
                                .can_be_done = !pickup_has_lamp,
                                .should_move = undefined,
                                .blocking = undefined,
                            };
                        },
                        .base => unreachable,
                        .altar => unreachable,
                    }
                },
            }
        }
        return null;
    }

    fn hasResource(self: *const Game, address: Vec2i) ?ResourceType {
        for (self.resources.items) |rsc| {
            if (rsc.address.equal(address)) return rsc.resource;
        }
        return null;
    }

    fn hasLamp(self: *const Game, address: Vec2i) bool {
        for (self.lamps.items) |lamp| {
            if (lamp.address.equal(address)) return true;
        }
        return false;
    }

    fn removeResource(self: *Game, address: Vec2i, end_address: Vec2i) void {
        for (self.resources.items) |*rsc| {
            if (rsc.address.equal(address)) {
                rsc.address = .{ .x = 10000, .y = 10000 };
                rsc.start_pos = rsc.position;
                rsc.end_pos = self.world.gridCenter(end_address);
                rsc.start_scale = 1;
                rsc.end_scale = 0;
                rsc.progress = 0;
                return;
            }
        }
        unreachable;
    }

    fn doAction(self: *Game, action: Action, actor: *Actor) void {
        if (!action.can_be_done) return;
        const str = self.structures.getPtr(action.structure);
        const slot = str.slots[action.slot_index].?;
        switch (slot) {
            .pickup => {
                const has_resource = self.hasResource(action.address);
                helpers.assert(has_resource != null);
                actor.carrying = has_resource;
                actor.energy -= 1;
                self.removeResource(action.address, action.address);
            },
            .dropoff => {
                const has_resource = self.hasResource(action.address);
                helpers.assert(has_resource == null);
                helpers.assert(actor.carrying != null);
                if (str.structure == .base) {
                    self.inventory[@intFromEnum(actor.carrying.?)] += 1;
                    self.resources.append(Resource.create(actor.carrying.?, action.address, str.address, false, self.world)) catch unreachable;
                } else {
                    self.resources.append(Resource.create(actor.carrying.?, action.address, action.address, true, self.world)) catch unreachable;
                }
                actor.carrying = null;
            },
            .action => {
                switch (str.structure) {
                    .mine => {
                        // can only do action if there is no resource in the pickup slot
                        const output_spot = str.address.add(str.orientation.toDir());
                        const has_resource = self.hasResource(output_spot);
                        helpers.assert(has_resource == null);
                        self.resources.append(Resource.create(.lead, str.address, output_spot, true, self.world)) catch unreachable;
                        actor.energy -= 1;
                    },
                    .combiner => {
                        const d0_has_resource = self.hasResource(str.address.add(str.orientation.opposite().toDir()));
                        const d1_has_resource = self.hasResource(str.address.add(str.orientation.opposite().next().toDir()));
                        const new_resource = ResourceType.fromValue(d0_has_resource.?.value() + d1_has_resource.?.value());
                        self.resources.append(Resource.create(new_resource, str.address, str.address.add(str.orientation.toDir()), true, self.world)) catch unreachable;
                        self.removeResource(str.address.add(str.orientation.opposite().toDir()), str.address);
                        self.removeResource(str.address.add(str.orientation.opposite().next().toDir()), str.address);
                        actor.energy -= 1;
                    },
                    .lamp => {
                        const output_spot = str.address.add(str.orientation.toDir());
                        self.lamps.append(Lamp.create(output_spot, self.world)) catch unreachable;
                    },
                    .base => unreachable,
                    .altar => unreachable,
                }
            },
        }
    }

    fn doMenuAction(self: *Game, action: MenuAction, index: usize) void {
        switch (action) {
            .none, .hide_menu => {},
            .set_mode_build_mine => {
                if (self.gems < COST_OF_MINE) return;
                self.builder.mode = .build;
                self.builder.structure = .mine;
            },
            .set_mode_build_altar => {
                if (self.gems < COST_OF_TRAP) return;
                self.builder.mode = .build;
                self.builder.structure = .altar;
            },
            .set_mode_build_lamp => {
                if (self.gems < COST_OF_LAMP) return;
                self.builder.mode = .build;
                self.builder.structure = .lamp;
            },
            .set_mode_loop_create => {
                self.builder.mode = .loop_create;
            },
            .set_mode_loop_delete => {
                self.builder.mode = .loop_delete;
                self.setupContextual();
            },
            .set_mode_djinn_manage => {
                self.builder.mode = .djinn_manage;
                self.setupContextual();
            },
            .action_loop_delete => {
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
            .action_start_game => {
                self.mode = .sunrise;
                self.setupSunriseMenu(true);
            },
            .action_start_day => {
                self.startDay();
                self.setupContextual();
                self.builder.open = false;
            },
            .action_ff_to_sunset => {
                self.forwardToSunset();
            },
            .action_start_night => {
                self.startNight();
                self.setupContextual();
            },
            .action_summon_djinn => {
                if (self.gems < self.djinn_summon_cost) return;
                self.djinns.addDjinn();
                self.gems -= self.djinn_summon_cost;
                // TODO (24 Jul 2024 sam): Have a more sophisticated cost increase curve.
                self.djinn_summon_cost += 2;
                self.resetMenu();
            },
            .set_mode_build_combiner => {
                if (self.gems < COST_OF_COMBINER) return;
                self.builder.mode = .build;
                self.builder.structure = .combiner;
            },
        }
    }

    fn startDay(self: *Game) void {
        self.mode = .day;
        self.djinns.resetEnergy();
        self.player.actor.energy = self.player.actor.total_energy;
        self.setupContextual();
        self.resetMenu();
    }

    fn startNight(self: *Game) void {
        self.day_count += 1;
        self.mode = .night;
        self.addShadows(self.day_count * 4);
        self.spirits.getPtr(self.stone_index).position = GRID_CELL_SIZE.scale(0.5);
        self.trail.reset();
        self.trail.beginTrail(self.player.position);
        self.resetMenu();
        self.resetLamps();
    }

    fn resetLamps(self: *Game) void {
        self.lamps.clearRetainingCapacity();
        // for player
        self.lamps.append(Lamp.create(.{}, self.world)) catch unreachable;
        self.lamps.items[0].radius = PLAYER_LIGHT_RADIUS;
    }

    fn forwardToSunset(self: *Game) void {
        self.ff_to_sunset = true;
        self.djinns.ff_steps = 1;
    }

    fn deletePath(self: *Game, path_index: PathIndex) void {
        self.paths.delete(path_index);
        self.djinns.removePath(path_index);
    }

    fn setupContextual(self: *Game) void {
        self.contextual.clearRetainingCapacity();
        switch (self.mode) {
            .sunrise, .day => {
                switch (self.builder.mode) {
                    .menu => {
                        for (self.paths.keys()) |pkey| {
                            const path = self.paths.getPtr(pkey);
                            const start = path.points.items[0];
                            const pos = self.world.gridCenterScreen(start);
                            self.contextual.append(.{
                                .text = .{
                                    .text = NUMBER_STR[self.djinns.pathCount(pkey)],
                                    .position = pos.add(.{ .y = 2 }),
                                    .color = colors.solarized_base03,
                                },
                            }) catch unreachable;
                        }
                    },
                    .loop_delete => {
                        for (self.paths.keys()) |pkey| {
                            const path = self.paths.getPtr(pkey);
                            const start = path.points.items[0];
                            const pos = self.world.gridCenterScreen(start);
                            self.contextual.append(.{ .button = .{
                                .rect = .{
                                    .position = pos.add(.{ .x = -30, .y = GRID_CELL_SIZE.y * -0.65 }),
                                    .size = .{ .x = 60, .y = 25 },
                                },
                                .text = "delete",
                                .value = @intFromEnum(MenuAction.action_loop_delete),
                                .index = pkey.index,
                            } }) catch unreachable;
                        }
                    },
                    .djinn_manage => {
                        for (self.paths.keys()) |pkey| {
                            const path = self.paths.getPtr(pkey);
                            const start = path.points.items[0];
                            const pos = self.world.gridCenterScreen(start);
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
                self.contextual.append(.{
                    .button = .{
                        .rect = .{ .position = .{ .x = SCREEN_SIZE.x - (GRID_CELL_SIZE.x * 3.8), .y = 10 }, .size = .{ .x = GRID_CELL_SIZE.x * 3.6, .y = 25 } },
                        .text = "End Day",
                        .value = @intFromEnum(MenuAction.action_ff_to_sunset),
                    },
                }) catch unreachable;
            },
            else => {},
        }
    }

    fn checkDayComplete(self: *Game) void {
        if (self.player.actor.energy == 0 and self.player.actor.carrying == null and !self.ff_to_sunset) self.forwardToSunset();
    }

    fn startSunrise(self: *Game) void {
        self.mode = .sunrise;
        self.setupSunriseMenu(true);
        self.setupContextual();
        self.day_count += 1;
    }

    fn startSunset(self: *Game) void {
        self.ff_to_sunset = false;
        self.mode = .sunset;
        self.djinns.ff_steps = 0;
        self.gems += self.inventory[0];
        self.gems += self.inventory[1] * 4;
        self.inventory = [_]u16{0} ** RESOURCE_COUNT;
        self.setupContextual();
        self.setupSunsetMenu();
        self.resources.clearRetainingCapacity();
    }

    fn resetMenu(self: *Game) void {
        self.menu.clearRetainingCapacity();
        if (self.mode == .sunrise) self.setupSunriseMenu(true);
        if (self.mode == .day) self.setupSunriseMenu(false);
        if (self.mode == .sunset) self.setupSunsetMenu();
    }

    pub fn saveGame(self: *Game) void {
        var stream = serializer.JsonStream.new(self.haathi.arena);
        var js = stream.serializer();
        js.beginObject() catch unreachable;
        serializer.serialize("game", self.*, &js) catch unreachable;
        js.endObject() catch unreachable;
        stream.webSave("save") catch unreachable;
        // stream.saveDataToFile("data/savefiles/save.json", self.arena) catch unreachable;
        // // always keep all the old saves just in case we need for anything.
        // const backup_save = std.fmt.allocPrint(self.arena, "data/savefiles/save_{d}.json", .{std.time.milliTimestamp()}) catch unreachable;
        // stream.saveDataToFile(backup_save, self.arena) catch unreachable;
    }

    pub fn loadGame(self: *Game) void {
        if (helpers.webLoad("save", self.haathi.arena)) |savefile| {
            const tree = std.json.parseFromSlice(std.json.Value, self.haathi.arena, savefile, .{}) catch |err| {
                helpers.debugPrint("parsing error {}\n", .{err});
                unreachable;
            };
            //self.sim.clearSim();
            serializer.deserialize("game", self, tree.value, .{ .allocator = self.haathi.allocator, .arena = self.haathi.arena });
            self.resetMenu();
            self.setupContextual();
        } else {
            helpers.debugPrint("no savefile found", .{});
        }
    }

    pub fn hitsStructure(self: *Game, spos: Vec2, vel: Vec2, shadow_index: ShadowIndex) ?Alert {
        var closest_dist_sqe: f32 = 10000000;
        var closest: Vec2 = .{};
        var strkey: ?StructureIndex = null;
        const end = spos.add(vel.scale(10000));
        for (self.structures.keys()) |skey| {
            const str = self.structures.getPtr(skey);
            const rect = self.world.cellToRect(str.address);
            if (rect.intersectsLine(spos, end)) |point| {
                const dist = point.distanceSqr(spos);
                if (strkey == null or dist < closest_dist_sqe) {
                    strkey = skey;
                    closest = point;
                    closest_dist_sqe = dist;
                }
            }
        }
        if (strkey) |skey| {
            const predicted_steps = @sqrt(closest_dist_sqe) / vel.length();
            return .{
                .target = skey,
                .target_pos = closest,
                .shadow = shadow_index,
                .predicted_steps = predicted_steps,
            };
        }
        return null;
    }

    fn createLoop(self: *Game, loop: []Vec2) void {
        const area = helpers.polygonArea(loop);
        if (area < LOOP_MIN_AREA) {
            return;
        }
        var destroyed = std.ArrayList(Destroyable).init(self.haathi.arena);
        for (self.shadows.shadows.items()) |*shadow| {
            if (shadow.death_count != null) continue;
            if (helpers.polygonContainsPoint(loop, shadow.position, null)) {
                shadow.markDead();
                destroyed.append(.{ .item = .shadow, .position = shadow.position }) catch unreachable;
                self.haathi.playSound("audio/capture.wav", false);
            }
        }
        for (self.structures.keys()) |skey| {
            const str = self.structures.getPtr(skey);
            if (str.health == 0) continue;
            const str_pos = self.world.cellToRect(str.address).center();
            if (helpers.polygonContainsPoint(loop, str_pos, null)) {
                self.damageStructure(skey, 1);
                destroyed.append(.{ .item = .structure, .position = str_pos }) catch unreachable;
            }
        }
        if (destroyed.items.len == 0) {
            // damage base
            self.damageStructure(.{ .index = 0 }, 3);
        }
        self.loops.append(Loop.init(self.allocator, loop, destroyed.items)) catch unreachable;
    }

    // updateGame
    pub fn update(self: *Game, ticks: u64) void {
        // clear the arena and reset.
        self.steps += 1;
        _ = self.arena_handle.reset(.retain_capacity);
        self.arena = self.arena_handle.allocator();
        self.ticks = ticks;
        const mouse_address = self.world.worldPosToAddress(self.world.screenToWorld(self.haathi.inputs.mouse.current_pos));
        var moving = false;
        if (true) {}
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
        self.player.updatePosition(self);
        if (!moving) self.player.dampVelocity();
        {
            var to_remove = std.ArrayList(usize).init(self.haathi.arena);
            for (self.resources.items, 0..) |*ra, i| {
                ra.update();
                if (ra.progress >= RESOURCE_ANIMATION_TICKS and ra.end_scale == 0) to_remove.insert(0, i) catch unreachable;
            }
            for (to_remove.items) |ri| _ = self.resources.swapRemove(ri);
        }
        if (BUILDER_MODE) {
            if (self.haathi.inputs.getKey(.num_1).is_down) self.ff_mode = true;
            if (self.haathi.inputs.getKey(.q).is_clicked) {
                self.saveGame();
            }
            if (self.haathi.inputs.getKey(.e).is_clicked) {
                self.loadGame();
            }
        }
        self.haathi.setCursor(.auto);
        switch (self.mode) {
            .day => {
                self.player.action_available = null;
                if (self.player.address.diagDistance(mouse_address) <= PLAYER_ACT_RANGE) {
                    self.player.action_available = self.actionAvailable(mouse_address, self.player.actor);
                }
                if (self.player.action_available != null and self.player.action_available.?.can_be_done and self.haathi.inputs.mouse.l_button.is_clicked) {
                    self.doAction(self.player.action_available.?, &self.player.actor);
                }
                if (self.haathi.inputs.getKey(.escape).is_clicked) {
                    helpers.debugPrint("escape0", .{});
                    if (!self.builder.hide_menu) self.builder.open = !self.builder.open;
                }
                if (BUILDER_MODE) {
                    if (self.haathi.inputs.getKey(.m).is_clicked) self.startSunset();
                }
                self.djinns.update(self);
                self.checkDayComplete();
                if (self.ff_to_sunset) {
                    self.haathi.setCursor(.progress);
                    if (self.djinns.energyRemaining()) {
                        for (0..self.djinns.ff_steps) |_| {
                            self.djinns.update(self);
                        }
                        self.djinns.ff_steps += 1;
                    } else {
                        self.startSunset();
                    }
                    if (self.djinns.ff_steps > FF_STEPS) {
                        for (0..EXTRA_FF_STEPS) |_| self.djinns.update(self);
                        self.startSunset();
                    }
                }
            },
            .night => {
                self.player.action_available = null;
                for (self.lamps.items) |*lamp| lamp.update();
                self.lamps.items[0].position = self.player.position;
                self.player.action_available = self.actionAvailable(mouse_address, self.player.actor);
                if (self.player.action_available != null and self.player.action_available.?.can_be_done and self.haathi.inputs.mouse.l_button.is_clicked) {
                    self.doAction(self.player.action_available.?, &self.player.actor);
                }
                self.trail.update(self.player.position);
                if (self.trail.intersection != null) {
                    self.createLoop(self.trail.points.items[self.trail.intersection_index..]);
                    self.trail.beginTrail(self.player.position);
                }
                self.shadows.update(self);
                for (self.structures.items()) |*str| str.update(self);
                for (self.loops.items) |*loop| loop.update();
                self.checkLoseScenario();
                self.checkWinScenario();
                self.alerts.update(self);
                self.alerts.play(self);
                if (BUILDER_MODE) {
                    if (self.haathi.inputs.getKey(.m).is_clicked) self.startSunrise();
                }
            },
            .lost => {
                if (self.haathi.inputs.getKey(.enter).is_clicked) self.reset();
            },
            .sunrise, .sunset, .new_game => {},
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
        if (self.handleMenu()) {
            switch (self.builder.mode) {
                .menu => {},
                .loop_create => {
                    self.builder.target = if (self.builder.current_path.points.items.len > 0) self.builder.current_path.getLastOrNull().?.orthoTarget(mouse_address) else mouse_address;
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
                        helpers.debugPrint("escape1", .{});
                        self.builder.mode = .menu;
                        self.builder.current_path.clear();
                        self.setupContextual();
                    }
                },
                .loop_delete => {
                    if (self.haathi.inputs.getKey(.escape).is_clicked) {
                        helpers.debugPrint("escape2", .{});
                        self.builder.mode = .menu;
                        self.builder.current_path.clear();
                        self.setupContextual();
                    }
                },
                .djinn_manage => {
                    if (self.haathi.inputs.getKey(.escape).is_clicked) {
                        helpers.debugPrint("escape3", .{});
                        self.builder.mode = .menu;
                        self.setupContextual();
                    }
                },
                .build => {
                    if (self.haathi.inputs.getKey(.r).is_clicked) self.builder.orientation = self.builder.orientation.next();
                    self.builder.can_build = self.canBuild(self.builder.structure, mouse_address);
                    if (self.haathi.inputs.mouse.l_button.is_clicked and self.builder.can_build) {
                        const skey = self.structures.getNextKey();
                        self.structures.append(.{ .structure = self.builder.structure, .address = mouse_address, .orientation = self.builder.orientation }) catch unreachable;
                        self.gems -= self.getStructureCost(self.builder.structure);
                        self.structures.getPtr(skey).setup(self.world);
                        self.builder.mode = .menu;
                        self.resetMenu();
                    }
                    if (self.haathi.inputs.getKey(.escape).is_clicked) {
                        helpers.debugPrint("escape4", .{});
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
                    if (!self.builder.hide_menu and item.button.value == @intFromEnum(MenuAction.hide_menu)) self.builder.hide_menu = item.button.hovered or item.button.triggered;
                }
            }
            if (BUILDER_MODE) {
                if (self.haathi.inputs.getKey(.m).is_clicked) if (self.mode == .sunrise) self.startDay() else self.startNight();
                if (self.haathi.inputs.getKey(.g).is_clicked) {
                    self.gems += 10;
                    if (self.day_count == 1) self.day_count = 2;
                    self.resetMenu();
                }
            }
        }
    }

    fn canBuild(self: *Game, structure: StructureType, address: Vec2i) bool {
        switch (structure) {
            .mine => {
                return self.isOrePatch(address) and self.getStructure(address) == null;
            },
            .altar => {
                return self.getSlot(address) == null and self.getStructure(address) == null and self.validPathPosition(null, address) == null and !self.isOrePatch(address);
            },
            .combiner => {
                // no structure on cell, and ortho neighbors
                const space = [_]Vec2i{ .{}, .{ .x = 1 }, .{ .y = 1 }, .{ .x = -1 }, .{ .y = -1 } };
                for (space) |cell| {
                    const free = self.getStructure(address.add(cell)) == null;
                    if (!free) return false;
                }
                return true;
            },
            .lamp => {
                const space = [_]Vec2i{ self.builder.orientation.toDir(), self.builder.orientation.toDir() };
                for (space) |cell| {
                    const free = self.getStructure(address.add(cell)) == null;
                    if (!free) return false;
                }
                return true;
            },
            .base => unreachable,
        }
    }

    fn handleMenu(self: *Game) bool {
        switch (self.mode) {
            .sunrise, .sunset, .new_game, .lost => return true,
            .night => return false,
            .day => return self.builder.open,
        }
    }

    fn checkLoseScenario(self: *Game) void {
        const stone_position = self.spirits.getPtr(self.stone_index).position;
        const clamped_position = self.world.clampInWorldBounds(stone_position);
        if (!stone_position.equal(clamped_position)) self.mode = .lost;
    }

    fn checkWinScenario(self: *Game) void {
        if (self.shadows.allDead()) {
            self.startSunrise();
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
            if (str.address.equal(address)) return skey;
        }
        return null;
    }

    fn getSlot(self: *Game, address: Vec2i) ?SlotType {
        for (self.structures.keys()) |skey| {
            const str = self.structures.getPtr(skey);
            if (address.distancei(str.address) != 1) continue;
            const slot_orientation = Orientation.getRelative(str.address, address);
            const slot_opt = str.slots[slot_orientation.toIndex()];
            return slot_opt;
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

    fn structureCollision(self: *const Game, p0: Vec2, p1: Vec2) ?Vec2 {
        for (self.structures.constItems()) |str| {
            const rect = self.world.cellToRect(str.address);
            if (rect.contains(p1)) {
                helpers.debugPrint("strcollision", .{});
                return rect.intersectsLine(p0, p1);
            }
        }
        return null;
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
            for (self.structures.items()) |str| {
                if (helpers.lineContains(p0, p1, str.address)) return str.address;
            }
            for (self.paths.items()) |path| {
                if (path.validPathPosition(p0, p1)) |point| return point;
            }
            return null;
        } else {
            for (self.paths.items()) |path| {
                if (path.pathContains(p1)) |point| return point;
            }
            for (self.structures.items()) |str| {
                if (str.address.equal(p1)) return str.address;
            }
            return null;
        }
    }

    pub fn drawCellInset(self: *Game, address: Vec2i, inset: f32, color: Vec4) void {
        const pos = self.world.worldToScreen(self.world.cellToRect(address).position);
        self.haathi.drawRect(.{
            .position = .{ .x = pos.x + inset, .y = pos.y + inset },
            .size = GRID_CELL_SIZE.subtract(.{ .x = inset * 2, .y = inset * 2 }),
            .color = color,
        });
    }

    pub fn drawCellBorder(self: *Game, address: Vec2i, width: f32, color: Vec4) void {
        var path = self.haathi.arena.alloc(Vec2, 4) catch unreachable;
        const pos = self.world.worldToScreen(self.world.cellToRect(address).position);
        const hw = width / 2;
        const xdiff = GRID_CELL_SIZE.x - width;
        const ydiff = GRID_CELL_SIZE.y - width;
        path[0] = .{ .x = pos.x + hw, .y = pos.y + hw };
        path[1] = .{ .x = pos.x + hw + xdiff, .y = pos.y + hw };
        path[2] = .{ .x = pos.x + hw + xdiff, .y = pos.y + hw + ydiff };
        path[3] = .{ .x = pos.x + hw, .y = pos.y + hw + ydiff };
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
            self.haathi.drawLine(.{ .p0 = self.world.gridCenterScreen(p0), .p1 = self.world.gridCenterScreen(p1), .color = colors.solarized_yellow.alpha(0.4), .width = 12 });
        }
    }

    fn drawStructure(self: *Game, str: Structure) void {
        var alpha: f32 = 1;
        if (str.structure == .altar) alpha *= 0.4;
        if (str.health == 0) alpha *= 0.4;
        self.drawCellInset(str.address, 1, colors.solarized_blue.alpha(0.8 * alpha));
        self.haathi.drawText(.{
            .text = @tagName(str.structure),
            .position = (self.world.gridCenterScreen(str.address)),
            .color = colors.solarized_base03.alpha(alpha),
            .style = FONTS[1],
        });
        if (self.mode == .night or self.handleMenu()) {
            //health
            const start = self.world.gridCenterScreen(str.address).add(.{ .x = GRID_CELL_SIZE.x * -0.5, .y = GRID_CELL_SIZE.y * -0.5 + 3 });
            const end = start.add(.{ .x = GRID_CELL_SIZE.x });
            const health = @as(f32, @floatFromInt(str.health)) / @as(f32, @floatFromInt(str.structure.startingHealth()));
            self.haathi.drawLine(.{
                .p0 = start.add(.{ .x = -1, .y = -1 }),
                .p1 = end.add(.{ .x = 1, .y = -1 }),
                .color = colors.solarized_base3,
                .width = 6,
            });
            self.haathi.drawLine(.{
                .p0 = start,
                .p1 = start.lerp(end, health),
                .color = colors.solarized_base03,
                .width = 4,
            });
        }
        if (self.mode != .night) {
            for (str.slots, 0..) |slot, i| {
                if (slot) |stype| {
                    const address = str.address.add(Orientation.fromIndex(i).toDir());
                    const dir = Orientation.fromIndex(i).opposite().vec();
                    const perp = Orientation.fromIndex(i).opposite().next().vec();
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
                            const color = colors.solarized_cyan.alpha(0.4);
                            const center = (self.world.gridCenterScreen(address));
                            const edge = center.add(dir.scale(GRID_CELL_SIZE.x * 0.5));
                            self.haathi.drawLine(.{
                                .p0 = center,
                                .p1 = edge,
                                .width = GRID_CELL_SIZE.x * 0.3,
                                .color = color,
                            });
                            const p0 = edge.add(perp.scale(GRID_CELL_SIZE.x * 0.35));
                            const p1 = edge.add(perp.scale(-GRID_CELL_SIZE.x * 0.35));
                            const p2 = edge.add(dir.scale(GRID_CELL_SIZE.x * 0.15));
                            const tri = self.haathi.arena.alloc(Vec2, 3) catch unreachable;
                            tri[0] = p0;
                            tri[1] = p1;
                            tri[2] = p2;
                            self.haathi.drawPoly(.{ .points = tri[0..], .color = color });
                            self.drawCellInset(address, 8, color);
                        },
                        .action => {
                            self.drawCellInset(address, 5, colors.solarized_orange.alpha(0.4));
                        },
                    }
                }
            }
        }
    }

    fn getStructureCost(self: *Game, st: StructureType) usize {
        _ = self;
        return switch (st) {
            .base => 0,
            .mine => COST_OF_MINE,
            .altar => COST_OF_TRAP,
            .lamp => COST_OF_LAMP,
            .combiner => COST_OF_COMBINER,
        };
    }

    fn getMenuActionCost(self: *Game, action_value: u8) ?usize {
        const action: MenuAction = @enumFromInt(action_value);
        switch (action) {
            .set_mode_build_mine => return COST_OF_MINE,
            .set_mode_build_altar => return COST_OF_TRAP,
            .set_mode_build_lamp => return COST_OF_LAMP,
            .set_mode_build_combiner => return COST_OF_COMBINER,
            .action_summon_djinn => return self.djinn_summon_cost,
            else => return null,
        }
    }

    fn drawCross(self: *Game, address: Vec2i) void {
        const cent = (self.world.gridCenterScreen(address));
        const nw = (self.world.gridCenterScreen(address.add(.{ .x = -1, .y = 1 })));
        const ne = (self.world.gridCenterScreen(address.add(.{ .x = 1, .y = 1 })));
        const sw = (self.world.gridCenterScreen(address.add(.{ .x = -1, .y = -1 })));
        const se = (self.world.gridCenterScreen(address.add(.{ .x = 1, .y = -1 })));
        self.haathi.drawLine(.{ .p0 = nw.lerp(cent, 0.6), .p1 = se.lerp(cent, 0.6), .color = colors.solarized_red, .width = 12 });
        self.haathi.drawLine(.{ .p0 = ne.lerp(cent, 0.6), .p1 = sw.lerp(cent, 0.6), .color = colors.solarized_red, .width = 12 });
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
                const cell = self.world.cell_origin.add(.{ .x = @intCast(x), .y = @intCast(y) });
                self.drawCellInset(cell, 1, colors.solarized_base2.alpha(0.5));
            }
        }
        if (true) {
            self.drawCellInset(GRID_SIZE, 2, colors.solarized_cyan);
        }
        if (true) {
            const cell = self.world.worldPosToAddress(self.world.screenToWorld(self.haathi.inputs.mouse.current_pos));
            self.drawCellInset(cell, 1, colors.solarized_red);
        }
        //if (true) return;
        // draw ore
        for (self.world.ore_patches.items) |patch| {
            self.drawCellInset(patch.position, 3, colors.solarized_base1.alpha(0.5));
        }
        const frame: f32 = @floatFromInt((self.steps / 6) % 4);
        const djinn_sprite_walking = haathi_lib.Sprite{ .path = "/img/djinn_walking.png", .anchor = .{ .x = 15 * frame }, .size = .{ .x = 15, .y = 28 } };
        const djinn_sprite_carrying = haathi_lib.Sprite{ .path = "/img/djinn_carrying.png", .anchor = .{ .x = 15 * frame }, .size = .{ .x = 15, .y = 28 } };
        // draw resources
        const mouse_address = self.world.worldPosToAddress(self.world.screenToWorld(self.haathi.inputs.mouse.current_pos));
        for (self.paths.items()) |path| {
            self.drawPath(path);
        }
        self.drawPath(self.builder.current_path);
        if (self.builder.current_path.getLastOrNull()) |p0| {
            const p1 = self.builder.target;
            self.haathi.drawLine(.{ .p0 = self.world.gridCenterScreen(p0), .p1 = self.world.gridCenterScreen(p1), .color = colors.solarized_yellow.alpha(0.2), .width = 10 });
        }
        for (self.djinns.djinns.items()) |djinn| {
            const alpha: f32 = if (djinn.actor.energy == 0 and djinn.actor.carrying == null) 0.4 else 1;
            const sprite = spr: {
                if (djinn.actor.carrying == null) {
                    break :spr djinn_sprite_walking;
                } else {
                    break :spr djinn_sprite_carrying;
                }
            };
            const dj_position = self.world.worldToScreen(djinn.position).add(sprite.size.scale(-0.5)).add(.{ .y = 10 });
            self.haathi.drawSprite(.{
                .sprite = sprite,
                .position = dj_position,
                .x_flipped = djinn.movingLeft(),
                //.scale = .{ .x = 0.5, .y = 0.5 },
            });
            // self.haathi.drawRect(.{
            //     .position = djinn.position.add(DJINN_SIZE.scale(-0.5)),
            //     .size = DJINN_SIZE,
            //     .color = colors.solarized_magenta.alpha(alpha),
            // });
            { //energy
                const start = self.world.worldToScreen(djinn.position).add(.{ .x = (-GRID_CELL_SIZE.x / 2) + 3, .y = (-GRID_CELL_SIZE.y / 2) + 5 });
                const end = self.world.worldToScreen(djinn.position).add(.{ .x = (GRID_CELL_SIZE.x / 2) - 3, .y = (-GRID_CELL_SIZE.y / 2) + 5 });
                self.haathi.drawLine(.{
                    .p0 = start.add(.{ .x = -1 }),
                    .p1 = end.add(.{ .x = 1 }),
                    .color = colors.solarized_base03.alpha(alpha),
                    .width = 8,
                });
                const energy: f32 = @as(f32, @floatFromInt(djinn.actor.energy)) / @as(f32, @floatFromInt(djinn.actor.total_energy));
                self.haathi.drawLine(.{
                    .p0 = start,
                    .p1 = start.lerp(end, energy),
                    .color = colors.solarized_base3.alpha(alpha),
                    .width = 6,
                });
            }
            if (djinn.actor.carrying) |rsc| {
                const framei: usize = @intFromFloat(frame);
                self.haathi.drawSprite(.{
                    .position = dj_position.add(ORE_START_OFFSET.scale(1)).add(.{
                        .x = if (djinn.movingLeft()) ORE_START_OFFSET.x * -2 else 0,
                        .y = ORE_ANIMATION_OFFSETS[framei],
                    }),
                    .sprite = ORE_SPRITES[rsc.value()],
                    //.scale = .{ .x = 0.5, .y = 0.5 },
                });
                //self.haathi.drawText(.{ .text = NUMBER_STR[rsc.value()], .position = rpos, .color = colors.white.alpha(0.5), .style = FONTS[1] });
            }
        }
        for (self.resources.items) |rsc| {
            self.haathi.drawSprite(.{
                .position = self.world.worldToScreen(rsc.position),
                .sprite = ORE_SPRITES[rsc.resource.value()],
                .scale = .{ .x = rsc.scale, .y = rsc.scale },
                .anchor = .center,
            });
        }
        if (self.builder.mode != .menu) self.haathi.drawText(.{ .text = @tagName(self.builder.mode), .position = self.haathi.inputs.mouse.current_pos.add(.{ .y = -20 }), .style = FONTS[1], .color = colors.solarized_base03.alpha(0.7) });
        if (self.builder.mode == .loop_create) {
            // draw mouse
            self.drawCellInset(mouse_address, 10, colors.solarized_yellow);
            //self.haathi.drawRect(.{
            //    .position = self.haathi.inputs.mouse.current_pos,
            //    .size = .{ .x = 10, .y = 10 },
            //    .color = colors.solarized_orange,
            //});
        }
        if (self.builder.invalid) |cell| {
            self.drawCross(cell);
        }
        if (self.builder.mode == .build) {
            var temp_str = Structure{ .address = mouse_address, .orientation = self.builder.orientation, .structure = self.builder.structure };
            temp_str.setup(self.world);
            self.drawStructure(temp_str);
            if (!self.builder.can_build) {
                self.drawCross(mouse_address);
            }
        }
        if (self.mode == .day and self.djinns.ff_steps > 0) {
            self.haathi.drawText(.{ .text = "Forwarding to end of day...", .position = SCREEN_SIZE.scaleVec2(.{ .x = 0.5, .y = 0.7 }), .color = colors.solarized_red });
        }
        if (self.mode == .night) {
            self.haathi.drawRect(.{
                .position = .{},
                .size = SCREEN_SIZE,
                .color = colors.solarized_base03.alpha(0.3),
            });
            // for (self.spirits.items()) |spirit| {
            //     self.haathi.drawRect(.{
            //         .position = self.world.worldToScreen(spirit.position),
            //         .centered = true,
            //         .radius = SPIRIT_LIGHT_RADIUS,
            //         .size = SPIRIT_LIGHT_SIZE,
            //         .color = colors.solarized_blue.alpha(0.6),
            //     });
            // }
            // draw player light
            for (self.lamps.items) |lamp| {
                const beam_multiplier = @as(f32, @floatFromInt(lamp.target_countdown)) / LAMP_RESET_TICKS;
                const light_multiplier = 1 - beam_multiplier;
                self.haathi.drawRect(.{
                    .position = self.world.worldToScreen(lamp.position),
                    .centered = true,
                    .radius = lamp.radius,
                    .size = .{ .x = lamp.radius * 2, .y = lamp.radius * 2 },
                    .color = colors.solarized_base3.alpha(0.6 * light_multiplier),
                });
                if (lamp.target) |skey| {
                    const shadow = self.shadows.shadows.getPtr(skey);
                    self.haathi.drawLine(.{
                        .p0 = self.world.worldToScreen(lamp.position),
                        .p1 = self.world.worldToScreen(shadow.position),
                        .color = colors.solarized_red.lerp(colors.solarized_base3, 0.8).alpha(beam_multiplier),
                        .width = 12,
                    });
                }
            }
            for (self.shadows.shadows.keys()) |skey| {
                const shadow = self.shadows.shadows.getPtr(skey);
                if (shadow.dead) continue;
                const scale: f32 = if (shadow.death_count != null) @as(f32, @floatFromInt(shadow.death_count.?)) / LOOP_KILL_TICKS else 1;
                const color = shadow.shadow.color();
                self.haathi.drawRect(.{
                    .position = self.world.worldToScreen(shadow.position),
                    .size = shadow.shadow.size(),
                    .color = color.alpha(scale),
                    .centered = true,
                });
                if (skey.index < NUMBER_STR.len) {
                    self.haathi.drawText(.{
                        .text = NUMBER_STR[skey.index],
                        .position = self.world.worldToScreen(shadow.position),
                        .color = colors.white,
                        .style = FONTS[1],
                    });
                }
            }
            for (self.spirits.items()) |spirit| {
                self.haathi.drawRect(.{
                    .position = self.world.worldToScreen(spirit.position).add(SPIRIT_SIZE.scale(-0.5)),
                    .size = SPIRIT_SIZE,
                    .color = colors.solarized_blue.lerp(colors.white, 0.5),
                });
            }
            for (self.structures.items()) |altar| {
                if (altar.structure != .altar) continue;
                self.haathi.drawRect(.{
                    .position = self.world.worldToScreen(altar.position).add(GRID_CELL_SIZE.scale(-0.5)),
                    .size = GRID_CELL_SIZE,
                    .color = colors.solarized_magenta,
                });
                self.haathi.drawText(.{
                    .text = "altar",
                    .position = self.world.worldToScreen(altar.position),
                    .color = colors.white,
                });
            }
            for (self.loops.items) |loop| {
                const alpha: f32 = @as(f32, @floatFromInt(loop.life)) / LOOP_LIFE_TICKS;
                self.haathi.drawPoly(.{
                    .offset = self.world.center,
                    .points = loop.points.items,
                    .color = colors.white.alpha(0.4 * alpha),
                });
                self.haathi.drawPath(.{
                    .offset = self.world.center,
                    .points = loop.points.items,
                    .color = colors.solarized_red.lerp(colors.white, 0.4).alpha(alpha),
                    .width = 6,
                    .closed = true,
                });
                self.haathi.drawRect(.{
                    .position = self.world.worldToScreen(loop.center),
                    .size = .{ .x = 10, .y = 25 },
                    .color = colors.solarized_orange.alpha(alpha),
                    .centered = true,
                });
                if (loop.destroyed.items.len == 0) {
                    self.haathi.drawText(.{
                        .text = "Summoned in vain",
                        .position = self.world.worldToScreen(loop.center),
                        .color = colors.solarized_base03.alpha(alpha),
                        .alignment = .center,
                    });
                    self.haathi.drawLine(.{
                        .p0 = self.world.worldToScreen(loop.center),
                        .p1 = self.world.worldToScreen(.{}),
                        .color = colors.solarized_orange.alpha(alpha),
                    });
                }
                for (loop.destroyed.items) |dst| {
                    self.haathi.drawLine(.{
                        .p0 = self.world.worldToScreen(loop.center),
                        .p1 = self.world.worldToScreen(dst.position),
                        .color = colors.solarized_orange.alpha(alpha),
                    });
                }
            }
            // draw trail
            {
                const len = self.trail.points.items.len;
                if (len > 1) {
                    for (self.trail.points.items[0 .. len - 1], self.trail.points.items[1..]) |p0, p1| {
                        self.haathi.drawLine(.{
                            .p0 = self.world.worldToScreen(p0),
                            .p1 = self.world.worldToScreen(p1),
                            .color = colors.solarized_red.lerp(colors.white, 0.4),
                            .width = 6,
                        });
                        self.haathi.drawRect(.{
                            .position = self.world.worldToScreen(p1),
                            .size = .{ .x = 5, .y = 5 },
                            .centered = true,
                            .radius = 10,
                            .color = colors.white,
                        });
                    }
                    self.haathi.drawLine(.{
                        .p0 = self.world.worldToScreen(self.player.position),
                        .p1 = self.world.worldToScreen(self.trail.points.items[len - 1]),
                        .color = colors.solarized_red.lerp(colors.white, 0.4),
                        .width = 6,
                    });
                }
                if (self.trail.intersection) |point| {
                    self.haathi.drawRect(.{
                        .position = self.world.worldToScreen(point),
                        .size = .{ .x = 15, .y = 15 },
                        .centered = true,
                        .radius = 30,
                        .color = colors.white,
                    });
                    if (false) {
                        self.haathi.drawPoly(.{
                            .offset = self.world.center,
                            .color = colors.white,
                            .points = self.trail.points.items[self.trail.intersection_index..],
                        });
                    }
                }
            }
        }
        // draw structures
        for (self.structures.items()) |str| {
            self.drawStructure(str);
        }
        // draw player
        self.haathi.drawRect(.{
            .position = self.world.worldToScreen(self.player.position).add(PLAYER_SIZE.scale(-0.5)),
            .size = PLAYER_SIZE,
            .color = colors.solarized_red,
        });
        if (self.player.actor.carrying) |rsc| {
            self.haathi.drawSprite(.{
                .position = self.world.worldToScreen(self.player.position).add(PLAYER_SIZE.scale(-0.5)).add(PLAYER_SIZE.yVec()).add(PLAYER_SIZE.xVec().scale(0.5)),
                .sprite = ORE_SPRITES[rsc.value()],
                .anchor = .center,
            });
        }
        self.haathi.drawText(.{
            .text = "you",
            .position = self.world.worldToScreen(self.player.position).add(PLAYER_SIZE.scale(0.0)),
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
        if (self.mode == .night) {
            // timer
            // const start = Vec2{ .x = 122, .y = 20 };
            // const end = Vec2{ .x = SCREEN_SIZE.x - (GRID_CELL_SIZE.x * 1) - 2, .y = 20 };
            // self.haathi.drawText(.{ .text = "Night:", .position = .{ .x = start.x - 8, .y = 14 }, .color = colors.solarized_base03, .alignment = .right });
            // self.haathi.drawLine(.{ .p0 = start.add(.{ .x = -2 }), .p1 = end.add(.{ .x = 2 }), .width = 25, .color = colors.solarized_base3 });
            // const progress: f32 = @as(f32, @floatFromInt(self.night_ticks)) / @as(f32, @floatFromInt(NIGHT_TICKS));
            // self.haathi.drawLine(.{ .p0 = start, .p1 = start.lerp(end, progress), .width = 20, .color = colors.solarized_base03 });
        }
        if (self.player.action_available != null and self.player.action_available.?.can_be_done) {
            self.drawCellBorder(mouse_address, 4, colors.solarized_base03);
            const slot = self.structures.getPtr(self.player.action_available.?.structure).slots[self.player.action_available.?.slot_index].?;
            self.haathi.drawText(.{
                .text = @tagName(slot),
                .position = self.world.gridCenterScreen(self.player.action_available.?.address).add(GRID_CELL_SIZE.yVec().scale(0.55)),
                .color = colors.solarized_base03,
            });
        } else {
            if (self.actionAvailable(mouse_address, .{})) |action| {
                const slot = self.structures.getPtr(action.structure).slots[action.slot_index].?;
                self.haathi.drawText(.{
                    .text = @tagName(slot),
                    .position = self.world.gridCenterScreen(mouse_address).add(GRID_CELL_SIZE.yVec().scale(0.55)),
                    .color = colors.solarized_base03.alpha(0.6),
                });
            }
            self.drawCellBorder(self.world.worldPosToAddress(self.player.position), 1, colors.solarized_base03.alpha(0.3));
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
                    self.haathi.drawText(.{ .text = text.text, .position = text.position, .color = text.color, .alignment = text.alignment });
                },
            }
        }
        if (!self.builder.hide_menu and self.handleMenu()) {
            self.haathi.drawRect(.{
                .position = .{},
                .size = SCREEN_SIZE,
                .color = colors.solarized_base03.lerp(colors.solarized_orange, 0.3).alpha(0.3),
            });
            for (self.menu.items) |item| {
                switch (item) {
                    .button => |button| {
                        const alpha: f32 = if (button.enabled) 1 else 0.4;
                        const color = if (button.hovered) colors.solarized_base01.lerp(colors.solarized_base3, 0.4) else colors.solarized_base01;
                        self.haathi.drawRect(.{ .position = button.rect.position, .size = button.rect.size, .color = color.alpha(alpha), .radius = 4 });
                        const text_pos = button.rect.position.add(button.rect.size.scaleVec2(.{ .x = 0.0, .y = 1 }).add(.{ .x = 8, .y = -18 }));
                        self.haathi.drawText(.{ .text = button.text, .position = text_pos, .color = colors.solarized_base3.alpha(alpha), .alignment = .left });
                        if (self.getMenuActionCost(button.value)) |value| {
                            const text = std.fmt.allocPrintZ(self.haathi.arena, "[{d} gems]", .{value}) catch unreachable;
                            self.haathi.drawText(.{
                                .text = text,
                                .position = button.rect.position.add(button.rect.size.scaleVec2(.{ .x = 1, .y = 1 }).add(.{ .y = -18 })),
                                .color = colors.solarized_base3.alpha(alpha),
                                .style = FONTS[1],
                                .alignment = .right,
                            });
                        }
                    },
                    .rect => |rect| {
                        self.haathi.drawRect(.{ .position = rect.position, .size = rect.size, .color = colors.solarized_base02, .radius = 4 });
                    },
                    .text => |text| {
                        self.haathi.drawText(.{ .text = text.text, .position = text.position, .color = text.color, .alignment = text.alignment });
                    },
                }
            }
        }
        if (self.mode.shouldShowStats()) {
            const x_start = GRID_CELL_SIZE.x;
            {
                const text = std.fmt.allocPrintZ(self.haathi.arena, "Gems: {d}", .{self.gems}) catch unreachable;
                self.haathi.drawText(.{ .text = text, .position = .{ .x = x_start, .y = 75 }, .color = colors.solarized_base03, .alignment = .left });
            }
            {
                const text = std.fmt.allocPrintZ(self.haathi.arena, "Djinn: {d} / {d}", .{ self.djinns.availableDjinnCount(), self.djinns.djinns.count() }) catch unreachable;
                self.haathi.drawText(.{ .text = text, .position = .{ .x = x_start, .y = 100 }, .color = colors.solarized_base03, .alignment = .left });
            }
            {
                const text = std.fmt.allocPrintZ(self.haathi.arena, "Ore: {d}", .{self.inventory[0]}) catch unreachable;
                self.haathi.drawText(.{ .text = text, .position = .{ .x = x_start, .y = 50 }, .color = colors.solarized_base03, .alignment = .left });
            }
        }
        for (self.alerts.alerts.items) |alert| {
            const spos = self.shadows.shadows.getPtr(alert.shadow).position;
            self.haathi.drawLine(.{
                .p0 = self.world.worldToScreen(spos),
                .p1 = self.world.worldToScreen(alert.target_pos),
                .color = colors.solarized_red,
            });
        }
        if (false) {
            const rect = self.world.cellToRect(self.player.address);
            self.haathi.drawRect(.{
                .position = self.world.worldToScreen(rect.position),
                .size = rect.size,
                .color = colors.solarized_blue,
            });
        }
        if (false) {
            const pos = self.world.screenToWorld(self.haathi.inputs.mouse.current_pos);
            const rect = self.world.cellToRect(self.world.worldPosToAddress(pos));
            self.haathi.drawRect(.{
                .position = self.world.worldToScreen(rect.position),
                .size = rect.size,
                .color = colors.solarized_green,
            });
        }
        if (false) { // testing lerp
            const center = Vec2i{};
            const target = center.orthoTarget(mouse_address);
            self.drawCellInset(target, 10, colors.white);
        }
    }
};
