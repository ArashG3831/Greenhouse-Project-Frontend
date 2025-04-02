import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';

export default defineConfig({
	plugins: [sveltekit()], 
	server : {
		allowedHosts: true
	},
	build: {
		rollupOptions: {
			output: {
				entryFileNames: 'assets/[name].[hash].js',
				chunkFileNames: 'assets/[name].[hash].js',
				assetFileNames: 'assets/[name].[hash].[ext]'
			}
		}
	}



});
