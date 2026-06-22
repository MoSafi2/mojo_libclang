#!/usr/bin/env node
import { access, readdir, readFile, writeFile } from 'fs/promises';
import { constants } from 'fs';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const contentDir = join(__dirname, '..', 'src', 'content', 'docs', 'api');

function titleFromFile(relativePath, baseName) {
  if (baseName === 'index.md' || baseName === '_index.md') {
    const parts = relativePath.split('/').filter(Boolean);
    const segment = parts.length > 1 ? parts[parts.length - 2] : 'API';
    return humanize(segment);
  }
  return humanize(baseName.replace(/\.md$/, ''));
}

function humanize(value) {
  return value
    .replace(/[-_]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .replace(/\b\w/g, (letter) => letter.toUpperCase());
}

async function walk(dir, relativeDir = '') {
  const entries = await readdir(dir, { withFileTypes: true });
  for (const entry of entries) {
    const full = join(dir, entry.name);
    const relativePath = relativeDir ? `${relativeDir}/${entry.name}` : entry.name;

    if (entry.isDirectory()) {
      await walk(full, relativePath);
      continue;
    }

    if (!entry.name.endsWith('.md')) continue;

    const content = await readFile(full, 'utf-8');
    if (content.startsWith('---')) continue;

    const title = titleFromFile(relativePath, entry.name);
    await writeFile(full, `---\ntitle: ${title}\n---\n\n${content}`);
  }
}

async function main() {
  try {
    await access(contentDir, constants.R_OK);
  } catch (err) {
    if (err.code === 'ENOENT') {
      console.error(
        `Error: API directory not found at ${contentDir}. Ensure 'modo build' completed successfully.`
      );
    } else {
      console.error(err);
    }
    process.exit(1);
  }

  await walk(contentDir);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
