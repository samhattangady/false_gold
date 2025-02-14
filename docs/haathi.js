var canvas = document.getElementById("haathi_canvas");
var ctx = canvas.getContext("2d");
ctx.imageSmoothingEnabled = false;
ctx.transform(1, 0, 0, -1, 0, canvas.height)
var images = {};
var sounds = {};

const keys = [
  " ",
  "alt",
  "control",
  "shift",
  "enter",
  "tab",
  "arrowdown",
  "arrowup",
  "arrowleft",
  "arrowright",
  "backspace",
  "delete",
  "escape",
  "meta",
  "a",
  "b",
  "c",
  "d",
  "e",
  "f",
  "g",
  "h",
  "i",
  "j",
  "k",
  "l",
  "m",
  "n",
  "o",
  "p",
  "q",
  "r",
  "s",
  "t",
  "u",
  "v",
  "w",
  "x",
  "y",
  "z",
  "1",
  "2",
  "3",
  "4",
  "5",
  "6",
  "7",
  "8",
  "9",
  "0",
  "[",
  "]",
  ";",
  "'",
  "\\",
  "/",
  ".",
  ",",
  "`",
];

const keycodes = {};
for (let i=0; i<keys.length; i++) keycodes[keys[i]] = i;

const getKeycode = (key) => {
  const code = keycodes[key.toLowerCase()];
  if (code === undefined) return keys.len + 20;  // return something out of scope.
  return code;
}

const wasmString = (ptr) => {
  const bytes = new Uint8Array(memory.buffer, ptr, memory.buffer.byteLength-ptr);
  let str = '';
  for (let i = 0; ; i++) {
    const c = String.fromCharCode(bytes[i]);
    if (c == '\0') break;
    if (c == 'Â') continue;  // hack for getting my ascii shrug into the game...
    str += c;
  }
  return str;
}

// TODO (25 Jul 2024 sam): There's probably a neater way to do this.
const wasmStringLen = (ptr, len) => {
  const bytes = new Uint8Array(memory.buffer, ptr, memory.buffer.byteLength-ptr);
  let str = '';
  for (let i = 0; i<len; i++) {
    const c = String.fromCharCode(bytes[i]);
    str += c;
  }
  return str;
}

const clearCanvas = (color) => {
  ctx.fillStyle = wasmString(color);
  ctx.fillRect(0, 0, canvas.width, canvas.height);
}

const debugPrint = (ptr) => {
  console.log(wasmString(ptr));
}

const milliTimestamp = () => {
  return BigInt(Date.now());
}

const fillRect = (x, y, width, height) => {
  ctx.fillRect(x, y, width, height);
}

const roundRect = (x, y, width, height, radius) => {
  ctx.roundRect(x, y, width, height, radius);
}

const fillStyle = (color) => {
  ctx.fillStyle = wasmString(color);
}

const strokeStyle = (color) => {
  ctx.strokeStyle = wasmString(color);
}

const lineWidth = (width) => {
  ctx.lineWidth = width;
}

const beginPath = () => {
  ctx.beginPath();
}

const closePath = () => {
  ctx.closePath();
}

const moveTo = (x, y) => {
  ctx.moveTo(x, y);
}

const lineTo = (x, y) => {
  ctx.lineTo(x, y);
}

const fill = () => {
  ctx.fill();
}

const stroke = () => {
  ctx.stroke();
}

const ellipse = (x, y, radius_x, radius_y, rotation, start_angle, end_angle, counter_clockwise) => {
  ctx.ellipse(x, y, radiusX, radiusY, rotation, startAngle, endAngle);
}

const font = (style) => {
  ctx.font = wasmString(style);
}

const textAlign = (alignment) => {
  ctx.textAlign = wasmString(alignment);
}

const fillText = (text, x, y, width) => {
  // we flip the canvas to get desirable x and y axis directions. But that results in text
  // being drawn upside down, so we adjust for that here.
  ctx.save();
  ctx.transform(1, 0, 0, -1, 0, canvas.height)
  ctx.fillText(wasmString(text), x, canvas.height-y, width);
  ctx.restore();
}

const setCursor = (style) => {
  document.body.style.cursor = wasmString(style).replace("_", "-");
}

const drawImage = (raw_image_path, sx, sy, sWidth, sHeight, dx, dy, dWidth, dHeight, x_flipped, y_flipped, rotation) => {
  const image_path = wasmString(raw_image_path);
  let image = images[image_path];
  if (image == undefined) {
    images[image_path] = new Image();
    images[image_path].src = image_path;
    image = images[image_path];
    //document.body.appendChild(image);
    console.log(image);
  }
  ctx.save();
  ctx.transform(1, 0, 0, -1, 0, canvas.height)
  ctx.translate(dx+(dWidth/2), canvas.height-dy-(dHeight/2));
  if (x_flipped) {
    ctx.scale(-1,1);
  }
  ctx.rotate(rotation * Math.PI/180);
  ctx.drawImage(image, sx, sy, sWidth, sHeight, -dWidth/2, dHeight/2, dWidth, -dHeight);
  ctx.restore();
}

// this approach means that a single sound can have only one instance at one time.
// so we cannot have a sound that is meant to overlap itself, unless it is represented
// by multiple sound_paths.
const loadSound = (raw_sound_path, loop) => {
  const sound_path = wasmString(raw_sound_path);
  sounds[sound_path] = new Audio(sound_path);
  sounds[sound_path].loop = loop;
  // TODO (09 Sep 2023 sam): We might need a way here to check if all the sounds are playable
}

// plays a sound. if restart=true, then restart sound
const playSound = (raw_sound_path, restart) => {
  const sound_path = wasmString(raw_sound_path);
  const sound = sounds[sound_path];
  // TODO (09 Sep 2023 sam): Check if a sound is marked as paused once it is completed...
  if (sound.paused || restart) {
    // TODO (09 Sep 2023 sam): Check that this plays sound from beginning.
    sound.load();
    sound.play();
  }
}

// pauses a sound that's playing.
const pauseSound = (raw_sound_path) => {
  const sound_path = wasmString(raw_sound_path);
  const sound = sounds[sound_path];
  sound.pause();
}

const setSoundVolume = (raw_sound_path, volume) => {
  const sound_path = wasmString(raw_sound_path);
  sounds[sound_path].volume = volume;
}

const webSave = (key, key_len, data, data_len) => {
  const key_name = wasmStringLen(key, key_len);
  const data_str = wasmStringLen(data, data_len);
  window.localStorage.setItem(key_name, data_str);
  console.log("saving", key_name, data_str);
}

const webLoadLen = (key, key_len) => {
  const key_name = wasmStringLen(key, key_len);
  const data = window.localStorage.getItem(key_name);
  if (data === null) return 0;
  return data.length;
}

const webLoad = (key, key_len, data_ptr, data_len) => {
  const key_name = wasmStringLen(key, key_len);
  const data = window.localStorage.getItem(key_name);
  const fileContents = new Uint8Array(memory.buffer, data_ptr, data_len);
  for (let i=0; i<data_len; i++) {
    fileContents[i] = data.charCodeAt(i);
  }
}

var api = {
  fillRect,
  roundRect,
  clearCanvas,
  debugPrint,
  milliTimestamp,
  fillStyle,
  strokeStyle,
  beginPath,
  closePath,
  moveTo,
  lineTo,
  lineWidth,
  fill,
  stroke,
  ellipse,
  font,
  fillText,
  textAlign,
  setCursor,
  drawImage,
  loadSound,
  playSound,
  pauseSound,
  setSoundVolume,
  webSave,
  webLoad,
  webLoadLen,
};
