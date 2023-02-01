// import PocketBase from '/dist/pocketbase.es.mjs';

const pb = new PocketBase('http://127.0.0.1:8090');

// *****************************************************************************
// Auth
// *****************************************************************************

// authenticate as admin using an email and password
// const authData = await pb.admins.authWithPassword('admin@foo.bar', 'admin@foo!123');

// auhenticate as app user
const authData = await pb.collection('users').authWithPassword('developer1@foo.bar', 'developer1@foo!123');

// after the above you can also access the auth data from the authStore
console.log('auth isValid:', pb.authStore.isValid);
console.log('auth token:', pb.authStore.token);
console.log('auth model.id:', pb.authStore.model.id);


const filter = {
    filter: 'created >= "2022-01-01 00:00:00" && someField1 != someField2',
};


// fetch a paginated records list
const resultList = await pb.collection('bookmarks').getList(1, 50);

// you can also fetch all records at once via getFullList
const records = await pb.collection('bookmarks').getFullList(200 /* batch size */, {
    sort: '-created',
});


const expand = {
    expand: 'relField1,relField2.subRelField',
};

// or fetch only the first record that matches the specified filter
const record = await pb.collection('bookmarks').getFirstListItem('title="GitHub"');

// *****************************************************************************
// DEBUG
// *****************************************************************************

console.log('resultList:', resultList);
console.log('records:', records);
console.log('record:', record);