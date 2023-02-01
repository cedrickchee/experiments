// *****************************************************************************
// File Upload Form
// *****************************************************************************
const formData = new FormData();

const fileInput = document.getElementById('fileInput');

// listen to file input changes and add the selected files to the form data
fileInput.addEventListener('change', async function () {
    console.log('file input changed');
    for (let file of fileInput.files) {
        formData.append('documents', file);
        console.log('formData appended');
    }
    console.log('file input: DONE');
    await upload();
});

async function upload() {
    // set some other regular text field value
    formData.append('title', 'A test post with a document');
    formData.append('body', '<h2>Some body</h2><p>Just a test</p>');

    // *****************************************************************************
    // PocketBase SDK
    // *****************************************************************************
    const pb = new PocketBase('http://127.0.0.1:8090');

    // auhenticate as app user
    const authData = await pb.collection('users').authWithPassword('developer1@foo.bar', 'developer1@foo!123');
    console.log('PB auth success');

    // upload and create new record
    const createdRecord = await pb.collection('posts').create(formData);

    console.log('file successfully uploaded');
}
