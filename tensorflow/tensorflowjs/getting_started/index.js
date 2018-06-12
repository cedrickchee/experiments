/**
 * 
 * Getting started with TensorFlow.js tutorial.
 * https://medium.com/tensorflow/getting-started-with-tensorflow-js-50f6783489b2?linkId=52869033
 * 
 */
async function learnLinear() {
    const model = tf.sequential();

    model.add(tf.layers.dense({ units: 1, inputShape: [1] }));
    model.compile({
        loss: 'meanSquaredError',
        optimizer: 'sgd'
    });

    const xs = tf.tensor2d([-1, 0, 1, 2, 3, 4], [6, 1]);
    const ys = tf.tensor2d([-3, -1, 1, 3, 5, 7], [6, 1]);

    await model.fit(xs, ys, { epochs: 500 });

    let outputField = document.getElementById('output_field');

    outputField.innerText = model.predict(tf.tensor2d([10], [1, 1]));
}

function main() {
    learnLinear();
}

main();
