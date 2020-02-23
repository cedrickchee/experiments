# Twitter Like REST API Example

This example demonstrates how to create a Twitter like REST API using:
- [JSON Web Tokens (JWT)](https://jwt.io/) for API security
- JSON for data exchange
- MongoDB for database

## Project Structure

```sh
$ tree
.
├── handler
│   ├── handler.go
│   ├── post.go
│   └── user.go
├── model
│   ├── post.go
│   └── user.go
└── server.go
```

## Database

Connect to MongoDB using CLI:

```sh
# First, check if MongoDB server is running. If not, start it
$ service mongod status
$ service mongod start

$ mongo localhost:27017
MongoDB shell version: 3.2.22
connecting to: localhost:27017/test
```

Switch to "twitter" database:

```sh
> show dbs
dev            0.031GB
keystone-demo  0.078GB
keystone-site  0.078GB
local          0.078GB
test           0.078GB
twitter        0.031GB

> use twitter
switched to db twitter

> show collections
system.indexes
users
```

Query "users" collections:

```sh
> db.users.find()
{ "_id" : ObjectId("5e51682fca201f71b14ce16a"), "email" : "john@foo.bar", "password" : "shhhhhhh!!" }
{ "_id" : ObjectId("5e51e82d4f676f0a14a33e58"), "email" : "david@foo.bar", "password" : "shhhhhhh!!", "followers" : [ "5e51e82d4f676f0a14a33e58", "5e51682fca201f71b14ce16a" ] }
{ "_id" : ObjectId("5e51edf94f676f5a0f247800"), "email" : "sean@foo.bar", "password" : "shhh!" }
```

Query "posts" collections:

```sh
> db.posts.find()
{ "_id" : ObjectId("5e51f2cf4f676f0fdc1d88c8"), "to" : "5e51e82d4f676f0a14a33e58", "from" : "5e51edf94f676f5a0f247800", "message" : "hello" }
{ "_id" : ObjectId("5e51f3234f676f0fdc1d88c9"), "to" : "5e51e82d4f676f0a14a33e58", "from" : "5e51edf94f676f5a0f247800", "message" : "wassup bro?" }
```

## API

### Signup

User signup

- Retrieve user credentials from the body and validate against database.
- For invalid email or password, send `400 - Bad Request` response.
- For valid email and password, save user in database and send `201 - Created` response.

#### Request

```sh
curl -X POST \
  http://localhost:3000/signup \
  -H "Content-Type: application/json" \
  -d '{"email":"john@foo.bar","password":"shhhhhhh!!"}'
```

#### Response

`201 - Created`

```js
{
  "id": "5e51682f4f676f318e9945b5",
  "email": "john@foo.bar",
  "password": "shhhhhhh!!"
}
```

### Login

User login

- Retrieve user credentials from the body and validate against database.
- For invalid credentials, send `401 - Unauthorized` response.
- For valid credentials, send `200 - OK` response:
  - Generate JWT for the user and send it as response.
  - Each subsequent request must include JWT in the `Authorization` header.

Method: `POST`<br>
Path: `/login`

#### Request

```sh
curl -X POST \
  http://localhost:3000/login \
  -H "Content-Type: application/json" \
  -d '{"email":"john@foo.bar","password":"shhhhhhh!!"}'
```

#### Response

`200 - OK`

```js
{
  "id": "5e51682f4f676f318e9945b5",
  "email": "jon@foo.bar",
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE1ODI2ODUwNzYsImlkIjoiNWU1MTY4MmY0ZjY3NmYzMThlOTk0NWI1In0.-vVVPUJ5K-B0NzpeH1SrIrxEOgc-Td6Tej_p_Ig4CDQ"
}
```

Client should store the token, for browsers, you may use local storage.

### Follow

Follow a user

- For invalid token, send `400 - Bad Request` response.
- For valid token:
  - If user is not found, send `404 - Not Found` response.
  - Add a follower to the specified user in the path parameter and send `200 - OK` response.

Method: `POST` <br>
Path: `/follow/:id`

#### Request

```sh
curl -X POST \
  http://localhost:3000/follow/5e51e82d4f676f0a14a33e58 \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE1ODI2ODUwNzYsImlkIjoiNWU1MTY4MmY0ZjY3NmYzMThlOTk0NWI1In0.-vVVPUJ5K-B0NzpeH1SrIrxEOgc-Td6Tej_p_Ig4CDQ"
```

#### Response

`200 - OK`

### Post

Post a message to specified user

- For invalid request payload, send `400 - Bad Request` response.
- If user is not found, send `404 - Not Found` response.
- Otherwise save post in the database and return it via `201 - Created` response.

Method: `POST` <br>
Path: `/posts`

#### Request

```sh
curl -X POST \
  http://localhost:3000/posts \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE1ODI2ODY5MTYsImlkIjoiNWU1MWVkZjk0ZjY3NmY1YTBmMjQ3ODAwIn0.etrHRu-qobl654k0OilaCCmCA_gxvt8dM1aBJpFrvPU" \
  -H "Content-Type: application/json" \
  -d '{"to":"5e51e82d4f676f0a14a33e58","message":"hello"}'
```

#### Response

`201 - Created`

```js
{
    "id":"5e51f2cf4f676f0fdc1d88c8",
    "to":"5e51e82d4f676f0a14a33e58",
    "from":"5e51edf94f676f5a0f247800",
    "message":"hello"
}
```

### Feed

List most recent messages based on optional `page` and `limit` query parameters

Method: `GET` <br>
Path: `/feed?page=1&limit=5`

#### Request

```sh
curl -X GET \
  http://localhost:3000/feed \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE1ODI2ODU0MzgsImlkIjoiNWU1MWU4MmQ0ZjY3NmYwYTE0YTMzZTU4In0.-mXoRPdizUnRG2DgtoaP775O6xWpWzpB00-sgvRdM4I"
```

#### Response

`200 - OK`

```js
[
    {
        "id":"5e51f2cf4f676f0fdc1d88c8",
        "to":"5e51e82d4f676f0a14a33e58",
        "from":"5e51edf94f676f5a0f247800",
        "message":"hello"
    }
]
```
