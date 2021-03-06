require! {
  'hindquarters'
  'lib/channels'
  'user/Game'
  'user/SaveGames'
  'user/game-store'
}

class User extends Backbone.DeepModel
  initialize: ->
    @listen-to this, \change:loggedIn, (user, logged-in) ~>
      if logged-in
        @upload-local-game! .then ~>
          if @_user-promise.is-fulfilled! then Promise.delay 300 .then -> window.location.reload!
      else
        if @_user-promise.is-fulfilled!
          unless window.location.hash.match /app/ then window.location.hash = '/menu'
          window.location.reload!

    @_user-promise = hindquarters.users.current!
      .then (data) ~>
        @set available: true
        @set device: data.device

        if data.logged-in then @set-user data.user else @set logged-in: false
      .catch (xhr) ~>
        @set available: xhr.status is 401
        @set-user null, false
        null
      .finally ~>
        Promise.delay 1000

  fetch: ~> @_user-promise

  logged-in: ~> @get \loggedIn
  purchased: ~> @logged-in! and @get \user .purchased

  set-user: (user, logged-in = true) ->
    if user?.status is 'creating' then window.location.hash = '/app/signup-next'
    @set logged-in: logged-in, user: user

  display-name: ->
    user = @get 'user'
    user.name

  full-name: ->
    user = @get \user
    "#{capitalize user.first-name or ''} #{capitalize user.last-name or ''}".trim!

  login: (username, password) ->
    hindquarters.auth.login {username, password}
      .then (user) ~> @set-user user.user

  logout: ->
    hindquarters.auth.logout!
    @set logged-in: false, user: null
    localforage.remove-item 'resume-id'

  subscribe: (body) ->
    hindquarters.users.subscribe (@get \user.id), body

  new-game: (stage-defaults) ->
    Game.new store: game-store!, user: (@get \user), stage-defaults: stage-defaults
      .tap (game) ~> @game = game

  load-game: (game) ->
    Game.load store: game-store!, user: (@get \user), id: game.id || game
      .tap (game) ~> @game = game

  recent-games: (limit = 10) ->
    game-store!
      .mine {limit}
      .then (games) ->
        new SaveGames games

  upload-local-game: ->
    store = game-store!
    if store.local then return # Cannot upload local to local
    local-store = require 'user/local-game-store'
    local-store.mine!
      .then (games) ->
        if games.length < 1 then return
        game = first games
        local-store.full game.id
          .tap (full-game) -> store.upload full-game
          .then ({game}) ~> local-store.delete-full game.id

module.exports = new User!
