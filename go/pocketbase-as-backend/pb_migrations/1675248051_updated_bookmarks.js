migrate((db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("60z03e9x1819ani")

  collection.listRule = ""

  return dao.saveCollection(collection)
}, (db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("60z03e9x1819ani")

  collection.listRule = null

  return dao.saveCollection(collection)
})
