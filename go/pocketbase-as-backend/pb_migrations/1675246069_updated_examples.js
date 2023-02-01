migrate((db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("60z03e9x1819ani")

  collection.name = "bookmarks"

  return dao.saveCollection(collection)
}, (db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("60z03e9x1819ani")

  collection.name = "examples"

  return dao.saveCollection(collection)
})
