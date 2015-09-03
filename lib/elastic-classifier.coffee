Os = require 'os'
Path = require 'path'
fs = require 'fs-plus'
Promise = require 'promise'
{CompositeDisposable} = require 'atom'
{allowUnsafeNewFunction} = require 'loophole'
elasticsearch = allowUnsafeNewFunction -> require 'elasticsearch'
ListView = require './list-view'

writeFile = Promise.denodeify(fs.writeFile)

config =
  getHost: ->
    atom.config.get('elastic-classifier.host')
  getIndex: ->
    atom.config.get('elastic-classifier.index')
  getDocType: ->
    atom.config.get('elastic-classifier.docType')
  getClassificationField: ->
    atom.config.get('elastic-classifier.classificationField')
  getQueryMaximumTerms: ->
    atom.config.get('elastic-classifier.queryMaximumTerms')
  getQueryMinimumShouldMatch: ->
    atom.config.get('elastic-classifier.queryMinimumShouldMatch')
  getQueryMatchFields: ->
    atom.config.get('elastic-classifier.queryMatchFields')
  getStopwords: ->
    atom.config.get('elastic-classifier.stopwords')

notifications =
  packageName: 'Elastic Classifier'
  addInfo: (message, {detail}={}) ->
    atom.notifications?.addInfo("#{@packageName}: #{message}", detail: detail)
  addError: (message, {detail}={}) ->
    atom.notifications.addError(
      "#{@packageName}: #{message}", detail: detail, dismissable: true)

Elasticsearch = ->
  client = new elasticsearch.Client(host: config.getHost())
  return client


queries =
  classificationAggregationQuery: ({size}={size: 0})->
    query =
      query: match_all: {}
      aggs: classifications: terms:
        field: config.getClassificationField()
        size: size
    return query

  significantTermsAggregationQuery: ({classification}={}) ->
    query =
      query: match: {}
      aggs: classifications:
        terms: field: config.getClassificationField()
        aggs: {}

    query.query.match[config.getClassificationField()] = classification

    for field in config.getQueryMatchFields()
      query.aggs.classifications.aggs[field] =
        significant_terms:
          field: field
          size: config.getQueryMaximumTerms()

    return query

  percolateQuery: ({keywords}={}) ->
    query =
      query: bool: must: []
      classification: config.getClassificationField()

    for field, values of keywords
      matchQuery = match: {}
      matchQuery.match[field] =
        query: values.join(' ')
        operator: 'or'
        minimum_should_match: config.getQueryMinimumShouldMatch()
      query.query.bool.must.push(matchQuery)

    return query

  searchClassifierQuery: ->
    query =
      query: match: classification: config.getClassificationField()
      size: 100
    return query

showClassifierQueryListView = (callback) ->
  client = Elasticsearch()
  options =
    index: config.getIndex()
    type: '.percolator'
    body:
      query: match: classification: config.getClassificationField()
      size: 100

  client.search(options).then((response) ->
    items = []
    for doc in response.hits.hits
      items.push(name: doc._id, id: doc._id)
    listView = new ListView(items, callback)
  ).catch((error) ->
    notifications.addError(error)
  )

showResponse = (response) ->
  fileName = Path.join Os.tmpDir(), "ElasticClassifier.json"
  text = JSON.stringify(response, null, 2)
  writeFile(fileName, text).then((args) ->
    atom.workspace.open(fileName, split: 'right', activatePane: true)
  )


module.exports = PercolateGenerator =
  subscriptions: null

  config:
    host:
      type: 'string'
      default: 'http://localhost:9200'
    index:
      type: 'string'
      default: 'blog'
    docType:
      type: 'string'
      default: 'posts'
    classificationField:
      type: 'string'
      default: 'tags'
    queryMaximumTerms:
      type: 'integer'
      default: 100
    queryMinimumShouldMatch:
      type: 'string'
      default: '2%'
    queryMatchFields:
      type: 'array'
      default: ['title', 'contents']
    stopwords:
      type: 'array'
      default: []


  activate: (state) ->
    @subscriptions = new CompositeDisposable
    @subscriptions.add atom.commands.add 'atom-workspace', 'elastic-classifier:generate-percolator-queries': => @generateCommand()
    @subscriptions.add atom.commands.add 'atom-workspace', 'elastic-classifier:get-percolator-query': => @getCommand()
    @subscriptions.add atom.commands.add 'atom-workspace', 'elastic-classifier:evaluate-percolator-queries': => @evaluateCommand()
    @subscriptions.add atom.commands.add 'atom-workspace', 'elastic-classifier:find-misclassifications': => @findMisclassificationsCommand()
    @subscriptions.add atom.commands.add 'atom-workspace', 'elastic-classifier:delete-percolator-query': => @deleteCommand()

  deactivate: ->
    @subscriptions.dispose()

  serialize: ->

  getCommand: ({id}={})->
    return showClassifierQueryListView(@getCommand) if not id

    client = Elasticsearch()
    options = index: config.getIndex(), type: '.percolator', id: id
    client.get(options).then((response) ->
      showResponse(response)
    )

  deleteCommand: ({id}={}) ->
    return showClassifierQueryListView(@deleteCommand) if not id

    client = Elasticsearch()
    options = index: config.getIndex(), type: '.percolator', id: id
    client.delete(options).then((response) ->
      text = JSON.stringify(response, null, 2)
      notifications.addInfo("Deleted", detail: text)
    )


  generateCommand: ->
    client = Elasticsearch()

    options =
      index: config.getIndex()
      type: config.getDocType()
      searchType: 'count'
      body: queries.classificationAggregationQuery()

    client.search(options).then((response) ->
      percolatorIds = []
      for classification in response.aggregations.classifications.buckets
        percolatorIds.push(classification.key)
        options =
          index: config.getIndex()
          type: config.getDocType()
          searchType: 'count'
          body: queries.significantTermsAggregationQuery(classification: classification.key)

        client.search(options).then((response) ->
          for classification in response.aggregations.classifications.buckets
            keywords = {}
            for field in config.getQueryMatchFields()
              keywords[field] = []
              for term in classification[field].buckets
                if term in config.getStopwords()
                  continue
                keywords[field].push(term.key)

            options =
              index: config.getIndex()
              type: '.percolator'
              id: classification.key
              body: queries.percolateQuery(keywords: keywords)

            client.index(options).catch((error) -> throw error)
        ).catch((error) -> throw error)
      return percolatorIds
    ).then((percolatorIds)->
      notifications.addInfo("Done",
        detail: "Percolator Ids: [#{percolatorIds}]")
    ).catch((error) ->
      notifications.addError(error)
    )

  evaluateCommand: ({id}={}) ->
    return showClassifierQueryListView(@evaluateCommand) if not id

    client = Elasticsearch()
    options = index: config.getIndex(), type: '.percolator', id: id
    client.getSource(options).then((response) ->
      includeFields = [config.getClassificationField()]
      includeFields.push(field) for field in config.getQueryMatchFields()
      options =
        index: config.getIndex()
        type: config.getDocType()
        body:
          query: response.query
          aggs: significantCategories:
            significant_terms: field: config.getClassificationField()
          fields: includeFields
          size: 100

      client.search(options).then((response) ->
        showResponse(response)
      )
    )

  findMisclassificationsCommand: ({id}={}) ->
    return showClassifierQueryListView(@findMisclassificationsCommand) if not id

    client = Elasticsearch()
    options = index: config.getIndex(), type: '.percolator', id: id
    client.getSource(options).then((response) ->
      query = response.query
      query.bool.must_not = match: {}
      query.bool.must_not.match[config.getClassificationField()] = id

      includeFields = [config.getClassificationField()]
      includeFields.push(field) for field in config.getQueryMatchFields()

      options =
        index: config.getIndex()
        type: config.getDocType()
        body:
          query: query
          aggs: significantCategories:
            significant_terms: field: config.getClassificationField()
          fields: includeFields
          size: 100

      client.search(options).then((response) ->
        showResponse(response)
      )
    )
