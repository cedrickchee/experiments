migrate((db) => {
  const collection = new Collection({
    "id": "60z03e9x1819ani",
    "created": "2023-02-01 09:07:35.701Z",
    "updated": "2023-02-01 09:07:35.701Z",
    "name": "examples",
    "type": "base",
    "system": false,
    "schema": [
      {
        "system": false,
        "id": "xaz6frxq",
        "name": "title",
        "type": "text",
        "required": false,
        "unique": false,
        "options": {
          "min": null,
          "max": null,
          "pattern": ""
        }
      },
      {
        "system": false,
        "id": "ttzlzltg",
        "name": "website",
        "type": "url",
        "required": true,
        "unique": false,
        "options": {
          "exceptDomains": null,
          "onlyDomains": null
        }
      }
    ],
    "listRule": null,
    "viewRule": null,
    "createRule": null,
    "updateRule": null,
    "deleteRule": null,
    "options": {}
  });

  return Dao(db).saveCollection(collection);
}, (db) => {
  const dao = new Dao(db);
  const collection = dao.findCollectionByNameOrId("60z03e9x1819ani");

  return dao.deleteCollection(collection);
})
