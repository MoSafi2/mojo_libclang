import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

export default defineConfig({
  site: 'https://mosafi2.github.io/mojo_libclang',
  base: '/mojo_libclang',
  integrations: [
    starlight({
      title: 'mojo_libclang',
      description:
        'High-level Mojo bindings for LLVM libclang and practical source-code tooling.',
      sidebar: [
        {
          label: 'Guide',
          items: [
            { label: 'Overview', link: '/' },
            { label: 'Setup', link: '/setup/' },
            { label: 'Examples', link: '/examples/' },
          ],
        },
        { label: 'API Reference', autogenerate: { directory: 'api' } },
      ],
      social: [
        {
          icon: 'github',
          label: 'GitHub',
          href: 'https://github.com/MoSafi2/mojo_libclang',
        },
      ],
    }),
  ],
  output: 'static',
});
