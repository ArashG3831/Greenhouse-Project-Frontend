import adapter from '@sveltejs/adapter-static';

export default {
	kit: {
		adapter: adapter(),
		alias: {
			$components: 'src/components'
		}
	}
};
