mongoose = require 'mongoose'
plugins = require '../../plugins/plugins'
AchievablePlugin = require '../../plugins/achievements'
jsonschema = require '../../../app/schemas/models/level_session'
log = require 'winston'

LevelSessionSchema = new mongoose.Schema({
  created:
    type: Date
    'default': Date.now
}, {strict: false})

LevelSessionSchema.index({creator: 1})
LevelSessionSchema.index({level: 1})
LevelSessionSchema.index({levelID: 1})
LevelSessionSchema.index({'level.majorVersion': 1})
LevelSessionSchema.index({'level.original': 1}, {name: 'Level Original'})
LevelSessionSchema.index({'level.original': 1, 'level.majorVersion': 1, 'creator': 1, 'team': 1})
LevelSessionSchema.index({playtime: 1}, {name: 'Playtime'})
LevelSessionSchema.index({submitDate: 1})
LevelSessionSchema.index({submitted: 1}, {sparse: true})
LevelSessionSchema.index({team: 1}, {sparse: true})
LevelSessionSchema.index({totalScore: 1}, {sparse: true})
LevelSessionSchema.index({user: 1, changed: -1}, {name: 'last played index', sparse: true})
LevelSessionSchema.index({'level.original': 1, 'state.topScores.type': 1, 'state.topScores.date': -1, 'state.topScores.score': -1}, {name: 'top scores index', sparse: true})

LevelSessionSchema.plugin(plugins.PermissionsPlugin)
LevelSessionSchema.plugin(AchievablePlugin)

previous = {}

LevelSessionSchema.post 'init', (doc) ->
  previous[doc.get 'id'] =
    'state.complete': doc.get 'state.complete'
    'playtime': doc.get 'playtime'

LevelSessionSchema.pre 'save', (next) ->
  User = require '../../users/User'  # Avoid mutual inclusion cycles
  @set('changed', new Date())

  id = @get('id')
  initd = id of previous
  levelID = @get('levelID')
  userID = @get('creator')
  activeUserEvent = null

  # Newly completed level
  if not (initd and previous[id]['state']?['complete']) and @get('state.complete')
    User.update {_id: userID}, {$inc: 'stats.gamesCompleted': 1}, {}, (err, count) ->
      log.error err if err?
    activeUserEvent = "level-completed/#{levelID}"

  # Spent at least 30s playing this level
  if not initd and @get('playtime') >= 30 or initd and (@get('playtime') - previous[id]['playtime'] >= 30)
    activeUserEvent = "level-playtime/#{levelID}"

  delete previous[id] if initd
  if activeUserEvent?
    User.saveActiveUser userID, activeUserEvent, next
  else
    next()

LevelSessionSchema.statics.privateProperties = ['code', 'submittedCode', 'unsubscribed']
LevelSessionSchema.statics.editableProperties = ['multiplayer', 'players', 'code', 'codeLanguage', 'completed', 'state',
                                                 'levelName', 'creatorName', 'levelID', 'screenshot',
                                                 'chat', 'teamSpells', 'submitted', 'submittedCodeLanguage',
                                                 'unsubscribed', 'playtime', 'heroConfig', 'team', 'transpiledCode',
                                                 'browser']
LevelSessionSchema.statics.jsonSchema = jsonschema

module.exports = LevelSession = mongoose.model('level.session', LevelSessionSchema, 'level.sessions')
