<script lang="coffee">
import AppConfig           from '@/shared/services/app_config'
import EventBus            from '@/shared/services/event_bus'
import AbilityService      from '@/shared/services/ability_service'
import AuthModalMixin      from '@/mixins/auth_modal'
import Session             from '@/shared/services/session'
import {tail, map, last, debounce}   from 'lodash'

export default
  mixins: [ AuthModalMixin ]
  data: ->
    title: AppConfig.theme.site_name
    isLoggedIn: Session.isSignedIn()
    group: null
    breadcrumbs: null
    sidebarOpen: false
    activeTab: ''
    showTitle: true
    page: null

  methods:
    toggleSidebar: -> EventBus.$emit 'toggleSidebar'
    toggleThreadNav: -> EventBus.$emit 'toggleThreadNav'
    signIn: -> @openAuthModal()
    last: last
    openSearchModal: ->
      EventBus.$emit 'openModal',
        component: 'SearchModal'
        persistent: false
        maxWidth: 900
        props:
          group: @group
          discussion: @discussion


  mounted: ->
    EventBus.$on 'sidebarOpen', (val) =>
      @sidebarOpen = val

    EventBus.$on 'signedIn', (user) =>
      @isLoggedIn = true

    EventBus.$on 'content-title-visible', (val) =>
      @showTitle = !val

    EventBus.$on 'currentComponent', (data) =>
      data = Object.assign({focusHeading: true}, data)
      if data.title?
        @title = data.title
      else if data.titleKey?
        @title = @$t(data.titleKey)

      @group = data.group
      @discussion = data.discussion
      @page = data.page

      if data.focusHeading
        setTimeout =>
          if document.querySelector('.v-main h1')
            document.querySelector('.v-main h1').focus()

  computed:
    groupName: ->
      return unless @group
      @group.name
    parentName: ->
      return unless @group
      @group.parentOrSelf().name
    groupPage: -> @page == 'groupPage'
    threadPage: -> @page == 'threadPage'
    logo: ->
      AppConfig.theme.app_logo_src
    icon: ->
      AppConfig.theme.icon_src
</script>

<template lang="pug">
v-app-bar.lmo-no-print(app clipped-right elevate-on-scroll color="background")
  //- template(v-slot:img="{ props }")
  //-   v-img(v-bind="props" gradient="rgba(0,0,0,.3), rgba(0,0,0, .3), rgba(0,0,0,.8)")

  v-btn.navbar__sidenav-toggle(icon @click="toggleSidebar()" :aria-label="$t(sidebarOpen ? 'navbar.close_sidebar' : 'navbar.open_sidebar')")
    v-avatar(tile size="36px")
      v-icon mdi-menu


  //- v-toolbar-title.group-cover-name(v-if="groupPage")
  //-   span {{group.name}}

  v-toolbar-title(v-if="showTitle" @click="$vuetify.goTo('head', {duration: 0})") {{title}}
  v-spacer
  v-btn(@click="openSearchModal" icon)
    v-icon mdi-magnify
  notifications(v-if='isLoggedIn')
  v-toolbar-items
  v-btn.navbar__sign-in(text v-if='!isLoggedIn' v-t="'auth_form.sign_in'" @click='signIn()')
</template>
