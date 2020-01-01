<script>
	export let name;

	let greet = 'Happy New Year!';
	let year = 2020;
	let src = 'tutorial/image.gif';
</script>

<main>
	<h1>Hello {name}!</h1>
	<p>{greet.toUpperCase()} Have a great {year}.</p>
	<img {src} alt="{name} dances"/>
	<span>A foobar span</span>
</main>

<style>
	main {
		text-align: center;
		padding: 1em;
		max-width: 240px;
		margin: 0 auto;
	}

	h1 {
		color: #ff3e00;
		text-transform: uppercase;
		font-size: 4em;
		font-weight: 100;
	}

	span {
		color: purple;
		font-family: 'Comic Sans MS', cursive;
		font-size: 2em;
	}

	@media (min-width: 640px) {
		main {
			max-width: none;
		}
	}
</style>