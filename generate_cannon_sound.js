#!/usr/bin/env bun

import { writeFileSync } from 'fs';

// Gera um som de tiro de canhão sintético
function generateCannonSound() {
  const sampleRate = 44100;
  const duration = 0.3; // 300ms
  const numSamples = Math.floor(sampleRate * duration);
  
  // Buffer para dados de áudio (16-bit PCM)
  const buffer = new ArrayBuffer(44 + numSamples * 2);
  const view = new DataView(buffer);
  
  // Cabeçalho WAV
  const writeString = (offset, string) => {
    for (let i = 0; i < string.length; i++) {
      view.setUint8(offset + i, string.charCodeAt(i));
    }
  };
  
  // RIFF header
  writeString(0, 'RIFF');
  view.setUint32(4, 36 + numSamples * 2, true);
  writeString(8, 'WAVE');
  
  // fmt chunk
  writeString(12, 'fmt ');
  view.setUint32(16, 16, true);
  view.setUint16(20, 1, true); // PCM
  view.setUint16(22, 1, true); // mono
  view.setUint32(24, sampleRate, true);
  view.setUint32(28, sampleRate * 2, true);
  view.setUint16(32, 2, true);
  view.setUint16(34, 16, true);
  
  // data chunk
  writeString(36, 'data');
  view.setUint32(40, numSamples * 2, true);
  
  // Gerar som de tiro de canhão
  let offset = 44;
  const timeStep = 1 / sampleRate;
  
  for (let i = 0; i < numSamples; i++) {
    const t = i * timeStep;
    
    // Combinação de ruído e frequências baixas para simular tiro
    let sample = 0;
    
    // Explosão inicial (ruído filtrado)
    if (t < 0.05) {
      const noise = (Math.random() - 0.5) * 0.8;
      const envelope = Math.exp(-t * 50);
      sample += noise * envelope;
    }
    
    // Som grave de canhão (frequência baixa)
    const lowFreq = Math.sin(2 * Math.PI * 60 * t) * 0.3;
    const lowFreq2 = Math.sin(2 * Math.PI * 80 * t) * 0.2;
    const envelope = Math.exp(-t * 3);
    sample += (lowFreq + lowFreq2) * envelope;
    
    // Eco/reverb
    if (t > 0.1 && t < 0.2) {
      const echo = (Math.random() - 0.5) * 0.1;
      sample += echo * Math.exp(-(t - 0.1) * 10);
    }
    
    // Normalizar e converter para 16-bit
    sample = Math.max(-1, Math.min(1, sample));
    const intSample = Math.floor(sample * 32767);
    view.setInt16(offset, intSample, true);
    offset += 2;
  }
  
  return buffer;
}

// Gerar e salvar o arquivo
try {
  const audioData = generateCannonSound();
  writeFileSync('sounds/shoot.wav', new Uint8Array(audioData));
  console.log('✅ Arquivo de áudio gerado: sounds/shoot.wav');
} catch (error) {
  console.error('❌ Erro ao gerar áudio:', error.message);
  process.exit(1);
}