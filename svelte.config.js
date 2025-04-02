import adapter from '@sveltejs/adapter-node';

const config = {
  kit: {
    adapter: adapter(),
    ssr: true  // this is default, but you can add it explicitly
  }
};

export default config;
