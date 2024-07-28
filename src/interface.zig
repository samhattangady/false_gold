pub extern fn fillRect(x: f32, y: f32, width: f32, height: f32) void;
pub extern fn roundRect(x: f32, y: f32, width: f32, height: f32, radius: f32) void;
pub extern fn clearCanvas(color: [*]const u8) void;
pub extern fn debugPrint(string: [*]const u8) void; // this needs to be null terminated.
pub extern fn milliTimestamp() i64;
pub extern fn fillStyle(color: [*]const u8) void;
pub extern fn strokeStyle(color: [*]const u8) void;
pub extern fn beginPath() void;
pub extern fn closePath() void;
pub extern fn fill() void;
pub extern fn stroke() void;
pub extern fn moveTo(x: f32, y: f32) void;
pub extern fn lineTo(x: f32, y: f32) void;
pub extern fn lineWidth(width: f32) void;
pub extern fn ellipse(x: f32, y: f32, rx: f32, ry: f32, start: f32, end: f32, counter: bool) void;
pub extern fn font(font: [*]const u8) void;
pub extern fn fillText(text: [*]const u8, x: f32, y: f32, width: f32) void;
pub extern fn textAlign(alignment: [*]const u8) void;
pub extern fn setCursor(style: [*]const u8) void;
pub extern fn drawImage(path: [*]const u8, sx: f32, sy: f32, sw: f32, sh: f32, dx: f32, dy: f32, dw: f32, dh: f32, x_flipped: bool, y_flipped: bool) void;
pub extern fn loadSound(path: [*]const u8, loop: bool) void;
pub extern fn playSound(path: [*]const u8, restart: bool) void;
pub extern fn pauseSound(path: [*]const u8) void;
pub extern fn setSoundVolume(path: [*]const u8, volume: f32) void;
pub extern fn webSave(key: [*]const u8, key_len: usize, data: [*]const u8, data_len: usize) void;
pub extern fn webLoadLen(key: [*]const u8, key_len: usize) usize;
pub extern fn webLoad(key: [*]const u8, key_len: usize, data_ptr: [*]u8, data_len: usize) void;
