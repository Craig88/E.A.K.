require! {
  'ui/ReactView'
  'ui/components/Donate'
  'ui/components/EndScreen'
  'ui/components/Login'
  'ui/components/SaveGames'
  'ui/components/Settings'
  'ui/components/SignUp'
  'ui/components/SignUpNext'
  'ui/components/Subscribe'
  'user'
}

cache = {}

module.exports = ({user, settings, $overlay-views, save-games, app}) ->
  $view-container = $overlay-views.find \#overlay-view-container
  get-new-view = (name) ->
    switch name
    | \donate => new ReactView component: Donate
    | \end => new ReactView component: EndScreen
    | \login => new ReactView component: Login
    | \myGames => new ReactView component: SaveGames, collection: save-games, app: app
    | \settings => new ReactView component: Settings, model: settings
    | \signup => new ReactView component: SignUp, model: user
    | \signupNext => new ReactView component: SignUpNext, model: user
    | \subscribe => new ReactView component: Subscribe
    | otherwise => throw new Error "view #name not found"

  (parent) -> (name) ->
    if cache[name] then return that
    try
      view = cache[name] = get-new-view name
        ..$el.append-to $view-container
        ..parent = parent

      return view
    catch e
      console.log e
      return null
