import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { env, StyleTextToSpeech2Model, AutoTokenizer } from '@huggingface/transformers';
import { KokoroTTS } from 'kokoro-js';

const folder = path.dirname(fileURLToPath(import.meta.url));
const app = path.resolve(process.argv[2]);
env.cacheDir = path.join(folder, '.cache');
const model = 'onnx-community/Kokoro-82M-v1.0-ONNX';
const voice = 'af_heart';
function pcm16(samples, rate) {
  let peak = 0;
  for (const value of samples) peak = Math.max(peak,Math.abs(value));
  const gain = peak > 0.98 ? 0.98/peak : 1;
  const wav = Buffer.alloc(44+samples.length*2);
  wav.write('RIFF',0); wav.writeUInt32LE(wav.length-8,4); wav.write('WAVEfmt ',8);
  wav.writeUInt32LE(16,16); wav.writeUInt16LE(1,20); wav.writeUInt16LE(1,22);
  wav.writeUInt32LE(rate,24); wav.writeUInt32LE(rate*2,28); wav.writeUInt16LE(2,32);
  wav.writeUInt16LE(16,34); wav.write('data',36); wav.writeUInt32LE(samples.length*2,40);
  for(let i=0;i<samples.length;i++) wav.writeInt16LE(Math.round(Math.max(-1,Math.min(1,samples[i]*gain))*32767),44+i*2);
  return wav;
}
const catalog = JSON.parse(await fs.readFile(path.join(app,'assets/questions.json'), 'utf8'));
const texts = [...new Set(catalog.questions.flatMap(q => q.answers.map(a => typeof a === 'string' ? a : a.text)))];
const out = path.join(app, 'assets/audio');
await fs.mkdir(out, {recursive:true});
const manifestPath = path.join(out,'manifest.json');
let previous;
try { previous = JSON.parse(await fs.readFile(manifestPath,'utf8')); } catch {}
if (previous?.compression) {
  throw new Error('This app uses compressed AAC audio. Generate WAV masters in a separate staging app, then compress and validate them before replacing the bundled catalog. Do not overwrite the release catalog with WAV.');
}
const manifest = {schemaVersion:1, model, voice, precision:'fp32', speed:1.0,
  sampleRate:24000, audioFormat:'PCM16 mono 24000 Hz WAV', generatedAt:new Date().toISOString(), clips:[]};
console.log('Loading local speech model...');
const tts = new KokoroTTS(
  await StyleTextToSpeech2Model.from_pretrained(model, {dtype:'fp32',device:'cpu',
    session_options:{intraOpNumThreads:8,interOpNumThreads:1}}),
  await AutoTokenizer.from_pretrained(model));
manifest.modelSha256 = crypto.createHash('sha256').update(
  await fs.readFile(path.join(env.cacheDir,model,'onnx/model.onnx'))).digest('hex');
for (const [i,text] of texts.entries()) {
  const textHash = crypto.createHash('sha256').update(text).digest('hex');
  const asset = `assets/audio/${textHash.slice(0,20)}.wav`;
  const filename = path.join(app,asset);
  const old = previous?.clips?.find(c => c.text === text && c.asset === asset);
  let reusable = false;
  if (old && previous.model === model && previous.voice === voice && previous.precision === 'fp32' &&
      previous.modelSha256 === manifest.modelSha256) {
    try { reusable = crypto.createHash('sha256').update(await fs.readFile(filename)).digest('hex') === old.fileSha256; } catch {}
  }
  if (!reusable) {
    const audio = await tts.generate(text,{voice,speed:1.0});
    await fs.writeFile(filename,pcm16(audio.audio,audio.sampling_rate));
  }
  let bytes = await fs.readFile(filename);
  // Convert float WAV clips from an earlier generator run to portable PCM16.
  if(bytes.readUInt16LE(20) === 3 && bytes.readUInt16LE(34) === 32) {
    const samples = new Float32Array((bytes.length-44)/4);
    for(let p=0;p<samples.length;p++) samples[p] = bytes.readFloatLE(44+p*4);
    bytes = pcm16(samples,bytes.readUInt32LE(24));
    await fs.writeFile(filename,bytes);
  }
  const seconds = (bytes.length - 44) / (24000 * 2);
  const rmsView = new DataView(bytes.buffer,bytes.byteOffset+44,bytes.length-44);
  let power = 0, peak = 0;
  for(let p=0; p+1<rmsView.byteLength; p+=2) {
    const value = rmsView.getInt16(p,true)/32768;
    power += value*value; peak = Math.max(peak,Math.abs(value));
  }
  const rms = Math.sqrt(power/(rmsView.byteLength/2));
  if (bytes.toString('ascii',0,4) !== 'RIFF' || seconds < 0.4 || seconds > 30 || rms < 0.001) {
    throw new Error(`Invalid generated clip: ${text}`);
  }
  manifest.clips.push({text, textSha256:textHash, asset, bytes:bytes.length,
    durationSeconds:Number(seconds.toFixed(3)), rms:Number(rms.toFixed(5)),
    peak:Number(peak.toFixed(5)), fileSha256:crypto.createHash('sha256').update(bytes).digest('hex')});
  await fs.writeFile(manifestPath,JSON.stringify(manifest,null,2)+'\n');
  console.log(`${i+1}/${texts.length}: ${text} (${seconds.toFixed(1)}s)`);
}
console.log('All bundled audio generated.');
