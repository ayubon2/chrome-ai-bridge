#!/usr/bin/env node
/**
 * CLI Entry Point for chrome-ai-bridge
 *
 * This entrypoint runs the MCP server in-process to avoid spawning an extra
 * wrapper process per client (important for multi-pane usage).
 */

import path from 'node:path';
import process from 'node:process';
import {fileURLToPath, pathToFileURL} from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const mockPath = path.join(__dirname, 'browser-globals-mock.mjs');
const mainPath = path.join(__dirname, '..', 'build', 'src', 'main.js');

try {
  // Ensure browser globals are defined before loading main server modules.
  await import(pathToFileURL(mockPath).href);
  await import(pathToFileURL(mainPath).href);
} catch (error) {
  const message = error instanceof Error ? error.stack || error.message : String(error);
  console.error(`[cli] Failed to start chrome-ai-bridge: ${message}`);
  process.exit(1);
}
