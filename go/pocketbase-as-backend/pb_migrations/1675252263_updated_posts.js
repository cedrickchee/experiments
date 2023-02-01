migrate((db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("kxfhgz72c2dyorp")

  collection.createRule = "@request.auth.id != \"\""
  collection.updateRule = "@request.auth.id != \"\""

  return dao.saveCollection(collection)
}, (db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("kxfhgz72c2dyorp")

  collection.createRule = null
  collection.updateRule = null

  return dao.saveCollection(collection)
})
