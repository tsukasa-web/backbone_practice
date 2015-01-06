"use strict"

###
Todo Model
-------------------
###
ToDo = Backbone.Model.extend
	defaults: ->
		title: 'empty todo ...'
		###taskの期限###
		deadline: 'empty deadline ...'
		###taskの優先度###
		priority: 'normal'
		###次のModelの順番の格納###
		order: Todos.nextOrder()
		###checkのstate###
		done: false
		###editのstate###
		editing: false

	###doneを反転して保存###
	toggle: ->
		this.save({done: !this.get('done')})


###
Todo Collection
-------------------
###
ToDoList = Backbone.Collection.extend
	model: ToDo
	sortAttribute: "order"
	sortDirection: 1
	###Modelをsort_keyの順に並べる###
	comparator: (a,b) ->
		a = a.get(this.sortAttribute)
		b = b.get(this.sortAttribute)

		if a is b
			return 0

		if this.sortDirection is 1
			return a > b ? 1 : -1
		else
			return a < b ? 1 : -1

	###LocalStorageへの保存###
	localStorage: new Backbone.LocalStorage('todos-backbone')

	###完了チェックが入ったToDoを返す###
	done: ->
		return this.where({done: true})

	###完了チェックが入っていないToDoを返す###
	remaining: ->
		return this.where({done: false})

	###次のModelの順番###
	nextOrder: ->
		if (!this.length)
			return 1
		return this.last().get('order') + 1

	sortByField: (fieldName) ->
		this.sortAttribute = fieldName
		this.sort()


Todos = new ToDoList


###
Todo Item View
-------------------
###
ToDoView = Backbone.View.extend
	tagName: 'li'
	###html上のテンプレートを宣言###
	template: _.template($('#item-template').html())

	events:
		'click .toggle': 'toggleDone'
		'dblclick .view': 'edit'
		'click a.destroy': 'clear'
		'keypress .edit-title': 'updateOnEnter'
		'click .edit-save': 'close'

	initialize: ->
		###Todoに変更イベントを設定###
		this.listenTo(this.model, 'change', this.render)
		###Todoに削除イベントを設定###
		this.listenTo(this.model, 'destroy', this.remove)

	render: ->
		###modelをJSONに変換してテンプレートに渡す###
		this.$el.html(this.template(this.model.toJSON()))
		###doneのクラスを持っているmodelのclassをtoggleによって外す###
		this.$el.toggleClass('done', this.model.get('done'))
		###priorityの値をクラスとして付加###
		this.$el.addClass(this.model.get('priority'))
		###priorityの値をedit-radio-listに反映###
		this.$el.find("input[name='edit-priority']").val([this.model.get('priority')])
		###オブジェクトとしてmodelの.edit-titleを保存###
		this.inputTitle = this.$('.edit-title')
		###オブジェクトとしてmodelの.edit-deadlineを保存###
		this.inputDeadline = this.$('.edit-deadline')
		###オブジェクトとしてmodelの.edit-radio-listを保存###
		this.inputPriority = this.$("input[name='edit-priority']")
		return this

	###対象modelのdoneを反転させる###
	toggleDone: ->
		this.model.toggle()

	###対象modelを編集中の状態に変更する###
	edit: ->
		this.model.edit = true
		this.$el.addClass('editing')
		this.inputTitle.focus()

	###Enterを押した際にcloseする###
	updateOnEnter: (e) ->
		if e.keyCode is 13
			this.close()

	###無記入ならclear、記入済みなら値を保存して編集状態を解除する###
	close : (e) ->
		e.preventDefault
		valueTitle = this.inputTitle.val()
		valueDeadline = this.inputDeadline.val()
		valuePriority = this.inputPriority.filter(':checked').val()
		if !valueDeadline
			alert('Input Deadline')
		else if !valueTitle
			this.clear()
		else
			this.model.edit = false
			this.model.save({
				title: valueTitle
				deadline: valueDeadline
				priority: valuePriority
			})
			this.$el.removeClass('editing')

	###対象modelを削除###
	clear: ->
		this.model.destroy()


###
App View is the top-level piece of UI.
-------------------
###

AppView = Backbone.View.extend
	el: $('#todoapp')
	###html上のテンプレートを宣言###
	statsTemplate: _.template($('#stats-template').html())

	events:
		'click #new-save':  'createOnEnter'
		'click #clear-completed': 'clearCompleted'
		'click #toggle-all': 'toggleAllComplete'
		'click #sort-add': 'sortAdd'
		'click #sort-deadline': 'sortDeadline'
		'click #sort-priority': 'sortPriority'

	initialize: ->
		this.list = this.$("#todo-list")
		this.inputTitle = this.$('#new-todo')
		this.inputDeadline = this.$('#new-deadline')
		this.inputPriority = this.$("input[name='priority']")
		this.allCheckbox = this.$('#toggle-all')[0]

		this.listenTo(this.collection, 'add', this.addOne)
		this.listenTo(this.collection, 'sort', this.reorder);
		this.listenTo(this.collection, 'all', this.render)

		this.footer = this.$('footer')
		this.main = $('#main')
		this.collection.fetch()

	render: ->
		###チェック済みmodelの数を取得###
		done = this.collection.done().length
		###未チェックmodelの数を取得###
		remaining = this.collection.remaining().length

		if Todos.length
			###Todoリストにタスクが入っている場合###
			this.main.show()
			this.footer.show()
			###現状のチェック状態をテンプレートに渡す###
			this.footer.html(this.statsTemplate({done: done, remaining: remaining}))
		else
			###Todoリストにタスクが入っていない場合###
			this.main.hide()
			this.footer.hide()

		###remainingが無い場合はallCheckboxにチェックを入れた状態にする###
		this.allCheckbox.checked = !remaining;

	###モデルを追加してリストをレンダリング###
	addOne: (todo) ->
		view = new ToDoView({model: todo})
		this.$('#todo-list').append(view.render().el)

	reorder: ->
		this.list.html('')
		this.addAll()

	###reset時に全部再レンダリング###
	addAll: ->
		this.collection.each(this.addOne, this)

	sortAdd: ->
		this.collection.sortByField('order')

	sortDeadline: ->
		this.collection.sortByField('deadline')

	sortPriority: ->
		this.collection.sortByField('priority')

	createOnEnter: (e) ->
		###空欄またはEnter押下時はreturn###
		if !this.inputTitle.val() or !this.inputDeadline.val()
			return
		###値をtitleにしてTodoに追加（この時addも発火）###
		this.collection.create({
			title: this.inputTitle.val()
			deadline: this.inputDeadline.val()
			priority: this.inputPriority.filter(':checked').val()
		})
		this.inputTitle.val('')

	###全モデルをチェック状態に変更###
	toggleAllComplete: ->
		done = this.allCheckbox.checked
		this.collection.each (todo) ->
			todo.save({'done': done})
			return
		return

	###チェック済みのモデルをdestroy###
	clearCompleted: ->
		_.invoke this.collection.done(), 'destroy'

App = new AppView({collection: Todos})