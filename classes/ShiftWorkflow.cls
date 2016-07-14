// ShiftWorkflow contains classes and interface to help build and display
// workflows. These workflows are built entirely in apex code, unlike the
// GUI-based Workflows bundled with the salesforce UI. The latter are useful for
// simple tasks, but don't scale well to our development process or to anything
// requiring sophisticated logic (or sensitivity to running correctly in
// sandboxes).
//
// This is an early version of the library and framework and is likely to change
// as our needs and workflow-building efforts evolve. The initial motivation was
// the PrOps workflow (see ShiftProcessingPipeline), but the need to coordinate
// and visualize a set of related tasks is pervasive enought to warrant its own
// library.
//
// The contents of this class are largely devoted to *execution* of workflows,
// but some of the interfaces and classes here also represent to *visualizing*
// the state of a workflow. The goal of this library is to allow developers to
// focus as much as possible on the logic of a workflow, and to provide
// generalized UI around task queues, statuses, and (eventually) analytics
// around queue and completion times for workflows and associated tasks. Most of
// this functionality is built on top fo the FormatSupport interface in this
// library, used in combination with the ShiftWorkflows page and
// ShiftWorkflowTask pages (see ShiftWorkflowsController and
// ShiftWorkflowTaskController).
//
// The core abstraction in a workflow is the Instance, for which we provide a
// base abstract implementation AbstractInstance. A workflow consists of some
// single object which represents the current state of the workflow, and some
// number of tasks or other actions which cause and are triggered by changes in
// that state. Because salesforce triggers work in bulk, Instance methods are
// phrased in terms of bulk operations.
//
// The logic of an instance is represented by Nodes and Actions. A Node
// encapsulates a check of some readiness condition, upon which readiness some
// Action is excuted. The action may lead to immediate updates to the workflow's
// state, or it may initiate an asynchronous process, such as inserting a task,
// which will at some later time lead to a state change.
//
// As a slightly less abstract example, imagine the following scenario (a
// simplified version of the initial vehicle processing pipeline):
//
//	- A state object Processing_Pipeline__c with fields Is_Inspection_Done__c,
//	Is_Detail_Done__c, and Is_Photography_Done__c.
//
//	- The desired workflow is that a vehicle must first be inspected, after
//	which both detailing and photography can proceed in parallel. Once both have
//	completed, a final step -- moving the car out of the Prepare stage, can be
//	completed.
//
// In terms of this library, we would have:
//
//	- An Instance which manages state objects of type Processing_Pipeline__c
//
//	- A task "Inspect Vehicle" which sets the Is_Inspection_Done__c field and
//	fires off the "Detail Vehicle" and "Photograph Vehicle" tasks.
//
//	- Simple checkbox nodes associated with each Is_Done__c field and set by the
//	associated tasks.
//
//	- A rendezvous node which awaits true values for both Is_Detail_Done__c and
//	Is_Photograph_Done__c before updating the stage for the associated
//	Opportunity.
// 
// For an example of a workflow in action, see ShiftWorkflowTesting and
// ShiftWorkflowTest, or for a more involved example, ShiftProcessingPipeline.
//
// In addition to implementing the interfaces in this class, implementations
// must:
//
//	1a. Register their instance with this class using registerInstanceType()
//	from inside a static class method.
//
//	1b. Invoke that static method from within the static block at the bottom of
//	this file.
//
//	2. Ensure that updates to and insertions of state objects are delivered to
//	the correct instance by calling processStateObjects() from inside a trigger
//	on the state object's type (see ShiftTestObject1Trigger for an example).
//
// Ideally none of the steps above would be required, but in the absence of a
// defined static initialization for Apex code or of a way to define triggers on
// generic SObjects, this is necessary. Potentially we can ameliorate this
// somewhat with code generation, but that's a lower priority.
public class ShiftWorkflow {
	// TODO: examples of or discussion about how to coordinate between
	// workflows or set up and track dependent workflows. Most likely this will
	// get added with the first version of repair management, which I
	// (jonathan@) plan to implement as dependent workflows to the main one in
	// ShiftProcessingPipeline.

	// An Instance coordinates application of some operation, in bulk, to a set
	// of state objects. Instances are typically used as follows:
	//
	//	- Something triggers updates to state objects (state objects are
	//	updated, tasks complete, etc)
	//
	//	- The instance processes its input, potentially generating a set of
	//	updates to state objects and new Tasks to insert.
	//
	//	- The instance applies all updates in bulk fashion, using as few DML
	//	operations as possible
	public interface Instance {
		// Gets the unique identifier for this Instance. The identifier is used
		// to register and retrieve instances.
		String getIdentifier();

		// Gets the version of this Instance. Versions can be useful in
		// workflows in which an Instance needs to gracefully handle completion
		// of Tasks spawned by a previous version.
		Integer getVersion();

		// Gets the state object appropriate to this instance for the given id
		// on which to make updates for the currently running operation.
		SObject getStateUpdate(Id id);

		// Enqueues a task to be inserted at some point before the next call to
		// applyUpdates() completes. The precise timing of the task's insertion
		// is implementation dependent, and this method's return does not imply
		// that the task has been inserted -- only that it will have been after
		// the next call to applyUpdates().
		void addTask(Task task);

		// Begins processing updates to tasks which are associated with this
		// Instance. Implementations can assume that Task.Workflow_Identifier__c
		// == getIdentifier() for all tasks in oldTasks or newTasks.
		void afterTaskUpdates(Map<Id, Task> oldTasks, List<Task> newTasks);

		// Begins processing after new state objects for this workflow Instance
		// are inserted.
		void stateObjectsInserted(List<SObject> newStates);

		// Begins processing after state objects for this workflow Instance are
		// updated
		void stateObjectsUpdated(Map<Id, SObject> oldState, List<SObject> newStates);

		// Concludes the most recent operation and writes changed state and
		// tasks to the database.
		void applyUpdates();
	}

	// An Action is executed when the Node to which it is associated becomes
	// ready.
	public interface Action {
		// Executes this action for the given state object managed by the given
		// instance.
		void execute(SObject state, Instance instance);
	}

	// A Node tracks the readiness of a state object for a single Action.
	public interface Node {
		// Indicates whether the given state represents readiness for this
		// Node's Action.
		Boolean isReady(SObject state);

		// Gets the Action to execute when this Node becomes ready. Result may
		// not be null.
		Action getAction();
	}

	// An ActionList executes a list of Actions as a single Action.
	public class ActionList implements Action {
		List<Action> actions;
		public ActionList(List<Action> actions) { this.actions = actions; }

		public void execute(SObject state, Instance instance) {
			for (Action a : actions) {
				a.execute(state, instance);
			}
		}
	}

	// Calls instance.addTask() with a Task created using default values for the
	// given instance.
	public static void addTask(Id whatId, String subject, String team, Instance instance) {
		instance.addTask(new Task(
			WhatId = whatId, 
			Subject = subject, 
			Team__c = team,
			Workflow_Identifier__c = instance.getIdentifier(),
			Workflow_Version__c = instance.getVersion(),
			OwnerId = ShiftUsers.unownedUserId()
		));
	}

	// TaskAdd actions insert a new Task for the associated instance.
	public class TaskAdd implements Action {
		String taskName;
		String taskTeam;
		
		public TaskAdd(String taskName, String taskTeam) {
			this.taskName = taskName;
			this.taskTeam = taskTeam;
		}

		public void execute(SObject state, Instance instance) {
			ShiftWorkflow.addTask(state.Id, taskName, taskTeam, instance);
		}
	}

	class NoOpAction implements Action {
		public void execute(SObject state, Instance instance) {}
	}

	// AbstractNode provides a starting point for Node implementation.
	public abstract class AbstractNode implements Node {
		final Action action; 
		public AbstractNode(Action action) { this.action = action; } 
		public Action getAction() { return action; }
	}

	// Rendezvous nodes await the readiness of a set of Nodes.
	public class Rendezvous extends AbstractNode {
		final List<Node> inbound;

		public Rendezvous(List<Node> inbound, Action action) { 
			super(action);
			this.inbound = inbound; 
		}
		
		public Boolean isReady(SObject state) {
			for (Node n : inbound) {
				if (!n.isReady(state)) {
					return false;
				}
			}
			return true;
		}
	}

	// FieldNodes become ready when a specified field contains an expected
	// value.
	public class FieldNode extends AbstractNode {
		// TODO: right now we only store the field and assume that it is of type
		// Checkbox (Boolean). We'll probably
		// want to store an explicit test value to account for other field
		// types as we grow this out. In particular, it's likely that we'll
		// wait on a certain count for a rollup field.
		Schema.SObjectField field;

		// Creates a FieldNode which waits for the given Boolean field to become
		// true.
		public FieldNode(Schema.SObjectField field, Action action) {
			super(action);
			this.field = field;
		}

		public FieldNode(Schema.SObjectField field) {
			this(field, new NoOpAction());
		}

		public Boolean isReady(SObject state) {
			// may need to allow overrides of this method
			return (Boolean) state.get(field) == true; // accounts for null
		}
	}

	// A TaskObserver observes and acts on changes to tasks.
	public interface TaskObserver {
		// Executes logic against instance (including doing nothing) based on
		// the given task change.
		void observe(Task oldTask, Task newTask, Instance instance);
	}

	// CompletionObserver executes an action upon completion of a task with one
	// of given set of subjects.
	public abstract class CompletionObserver implements TaskObserver {
		Set<String> subjects;

		public CompletionObserver(Set<String> subjects) { this.subjects = subjects; }
		public CompletionObserver(String subject) { this(new Set<String>{subject}); }

		// Called when this instance observes that t has just completed.
		public abstract void taskCompleted(Task t, Instance instance);
		
		public void observe(Task oldTask, Task newTask, Instance instance) {
			if (!subjects.contains(newTask.Subject)) {
				return;
			}
			if (oldTask.Status == newTask.Status || newTask.Status != ShiftConstants.TASK_STATUS_COMPLETED) {
				return;
			}
			taskCompleted(newTask, instance);
		}
	}
	
	// FieldSetter sets the value of a field upon completion of a task.
	public class FieldSetter extends CompletionObserver {
		// See the note in FieldNode: we currently assume only that we are
		// setting a true value for a boolean field, but that need not be a
		// fixed assumption.
		Schema.SObjectField field;

		// Sets a value of true for the given Boolean field when an expected
		// task completes.
		public FieldSetter(String subject, Schema.SObjectField field) { 
			super(subject);
			this.field = field; 
		}

		public override void taskCompleted(Task newTask, Instance instance) {
			instance.getStateUpdate(newTask.WhatId).put(field, true);
		}
	}

	// AbstractInstance provides a basic implementation of Instance.
	public abstract class AbstractInstance implements Instance {
		final Type stateType;
		final String identifier;
		final Integer version;

		// Provides a map of objects on which to call addError() in order to
		// communicate a processing error associated with the given id. The
		// reason we need this is that we often will perform an Action on
		// completion of a Task, passing Task.WhatId as the id of the state
		// object involved. If the Action needs to generate an error, it must
		// have a valid object on which to set that error. Since we don't want
		// to bind the Action interface to the Task which spawned it, we provide
		// this as a decoupled way to always have a way to associate an error
		// with an intended state object in a way which will be correctly
		// reported via the salesforce UI or API.
		protected final Map<Id, SObject> errorTargets = new Map<Id, SObject>();

		final Map<Id, SObject> stateUpdates = new Map<Id, SObject>();

		// The list of tasks to be inserted during applyUpdates()
		protected final List<Task> tasks = new List<Task>();

		final List<TaskObserver> observers = new List<TaskObserver>();
		final List<Node> nodes = new List<Node>();

		public AbstractInstance(Type stateType, String identifier, Integer version) { 
			this.stateType = stateType;
			this.identifier = identifier; 
			this.version = version;
		}

		public String getIdentifier() { return identifier; }
		public Integer getVersion() { return version; }

		public SObject getStateUpdate(Id stateId) {
			SObject res = stateUpdates.get(stateId);
			if (res == null) {
				res = (SObject) stateType.newInstance();
				res.Id = stateId;
				stateUpdates.put(stateId, res);
			}
			return res;
		}

		// The next section of methods represent a dsl-like attempt to make building up an
		// instance's behavior easy and readable for common cases. We take advantage of Apex
		// overloading in various places. In particular, we use overloading as a limited
		// replacement for variadic arguments, so in places where we might have the method
		//
		//	addFooAndBars(Foo foo, []Bar ...bars)
		//
		// we instead have
		//
		//	addFooAndBars(Foo foo, Bar bar1)
		//	addFooAndBars(Foo foo, Bar bar1, Bar bar2)
		//	addFooAndBars(Foo foo, Bar bar1, Bar bar2, Bar bar3)
		// 
		// manually adding more as needed. While not ideal, most uses should be covered with a
		// few handcoded methods.

		protected void addTaskObserver(TaskObserver o) { observers.add(o); }

		protected void addNode(Node n) { nodes.add(n); }

		protected void setFieldOnTask(Schema.SObjectField field, String subject) {
			addTaskObserver(new FieldSetter(subject, field));
		}

		protected void startActionOnFields(Action action, Schema.SObjectField field1) {
			addNode(new FieldNode(field1, action));
		}

		protected void startActionOnFields(Action action, Schema.SObjectField field1, Schema.SObjectField field2) {
			addNode(new Rendezvous(
				new List<Node>{new FieldNode(field1), new FieldNode(field2)},
				action
			));
		}

		protected void startTaskOnFields(String subject, String team, Schema.SObjectField field1) {
			startActionOnFields(actionAddTask(subject, team), field1);
		}

		protected void startTaskOnFields(String subject, String team, Schema.SObjectField field1, Schema.SObjectField field2) {
			startActionOnFields(actionAddTask(subject, team), field1, field2);
		}

		protected Action actionAddTask(String subject, String team) {
			return new TaskAdd(subject, team);
		}

		protected Action actionList(Action action1, Action action2) {
			return new ActionList(new List<Action>{action1, action2});
		}

		protected Action actionList(Action action1, Action action2, Action action3) {
			return new ActionList(new List<Action>{action1, action2, action3});
		}

		// END dsl methods

		public void addTask(Task t) {
			tasks.add(t);
		}

		public void addTask(Id stateId, String subject, String team) {
			ShiftWorkflow.addTask(stateId, subject, team, this);
		}

		// Subclasses can override this to execute custom logic as part of
		// applyUpdates(). This method will be called before any tasks are
		// inserted or state objects updates are committed, so updates to state
		// or to elements of tasks made by this method will be observed after
		// applyUpdates() completes.
		protected virtual void handleUpdates() {}

		public void applyUpdates() {
			handleUpdates();
			insert tasks;
			update stateUpdates.values();
		}

		public void afterTaskUpdates(Map<Id, Task> oldTasks, List<Task> newTasks) {
			for (Task newTask : newTasks) {
				Task oldTask = oldTasks.get(newTask.Id);
				errorTargets.put(newTask.WhatId, newTask);
				for (TaskObserver o : observers) {
					o.observe(oldTask, newTask, this);
				}
			}
		}

		void fireNode(Node n, SObject state) { n.getAction().execute(state, this); }

		public virtual void stateObjectsInserted(List<SObject> newStates) {
			// fires any Nodes that are ready immediately upon insert
			errorTargets.putAll(newStates);
			for (SObject state : newStates) {
				for (Node n : nodes) {
					if (n.isReady(state)) {
						fireNode(n, state);
					}
				}
			}
		}

		public virtual void stateObjectsUpdated(Map<Id, SObject> oldStates, List<SObject> newStates) {
			errorTargets.putAll(newStates);
			for (SObject newState : newStates) {
				SObject oldState = oldStates.get(newState.Id);
				for (Node n : nodes) {
					if (!n.isReady(oldState) && n.isReady(newState)) {
						fireNode(n, newState);
					}
				}
			}
		}
	}

	// Called after tasks are updated. This method is public but is only
	// intended to be called by code in the class ShiftTasks, which handles
	// trigger events on Task.
	public static void processTasksAfterUpdate(Map<Id, Task> oldTasks, List<Task> newTasks) {
		Map<String, List<Task>> workflowTasks = new Map<String, List<Task>>();
		for (Task t : newTasks) {
			String wid = t.Workflow_Identifier__c;
			if (wid == null) {
				continue;
			}
			List<Task> l = workflowTasks.get(wid);
			if (l == null) {
				l = new List<Task>();
				workflowTasks.put(wid, l);
			}
			l.add(t);
		}
		for (String wid : workflowTasks.keySet()) {
			Instance inst = newInstance(wid);
			if (inst == null) {
				continue;
			}
			inst.afterTaskUpdates(oldTasks, workflowTasks.get(wid));
			inst.applyUpdates();
		}
	}

	// Called by triggers on state objects after insert or update.
	// Implementations must arrange that this method is called explicitly. The
	// simplest form for a workflow 'foo' with state object type Shift_Foo__c
	// might be:
	//	
	//		trigger ShiftFooTrigger on Shift_Foo__c (after insert, after update) {
	//			ShiftWorkflow.processStateObjects('foo');
	//		}
	//
	// Note that this assumes the workflow has been separately registered with
	// the ShiftWorkflow class.
	public static void processStateObjects(String identifier) {
		Instance inst = newInstance(identifier);
		if (inst == null) {
			return;
		}
		if (Trigger.isAfter) {
			if (Trigger.isInsert) {
				inst.stateObjectsInserted(Trigger.new);
				inst.applyUpdates();
			} else if (Trigger.isUpdate) {
				inst.stateObjectsUpdated(Trigger.oldMap, Trigger.new);
				inst.applyUpdates();
			}
		}
	}

	// FormatSupport provides context for default visualization of workflow
	// instances and associated task queues. Workflow instances are not required
	// to support custom formatting, which is why this is a separate interface.
	// The default UI for workflows will work whether or not a FormatSupport
	// instance is registered for a given identifier, but FormatSupport can
	// provide a more polished experience when needed.
	public interface FormatSupport {
		// Returns a map, keyed by task id, of labels to use when displaying
		// that task in a workflow UI. By default such UIs will use
		// Task.What.Name. The returned map does not have to override all of the
		// tasks in the input (and may be empty, but should not be null).
		Map<Id, String> getTaskReferenceLabels(List<Task> tasks, Instance instance);

		// Returns a custom string to use when identifying this workflow in a UI.
		String getWorkflowLabel(Instance instance);

		// Returns a reference to a custom task detail and work page for the
		// given task. May be null to indicate that the caller should use the
		// default task work page.
		PageReference getTaskPageReference(Id taskId, Instance instance);

		// Returns a set of task ids associated with vehicles specified as "priority".
		Set<Id> getPriorityTaskIds(List<Task> tasks, Instance instance);
	}

	// DefaultFormatSupport provides a basis for FormatSupport implementation
	public virtual class DefaultFormatSupport implements FormatSupport {
		public virtual Map<Id, String> getTaskReferenceLabels(List<Task> tasks, Instance instance) {
			return new Map<Id, String>();
		}

		public virtual String getWorkflowLabel(Instance instance) {
			return instance.getIdentifier();
		}

		public virtual PageReference getTaskPageReference(Id taskId, Instance instance) { return null; }

		public virtual Set<Id> getPriorityTaskIds(List<Task> tasks, Instance instance) {
			return new Set<Id>();
		}
	}

	// Maps workflow identifiers to the Type of the object that implements
	// Instance or FormatSupport for that workflow. We can replace this later
	// with something more general like Map<String, InstanceFactory> if needed.
	static final Map<String, Type> INSTANCE_TYPES = new Map<String, Type>();
	static final Map<String, Type> FORMAT_SUPPORT_TYPES = new Map<String, Type>();

	static void setFirstEntry(Map<String, Type> types, String identifier, Type type) {
		Type prev = types.put(identifier, type);
		System.assert(prev == null, 'attempt to set both ' + type + ' and ' + prev + ' for workflow: ' + identifier);
	}

	static Object createType(Map<String, Type> types, String identifier) {
		Type t = types.get(identifier);
		return t == null ? null : t.newInstance();
	}

	// Sets the type used to generate Instances for the given workflow
	// identifier.
	public static void registerInstanceType(String identifier, Type type) {
		setFirstEntry(INSTANCE_TYPES, identifier, type);
	}

	// Returns a new Instance for the given identifier, or null if none is
	// registered.
	public static Instance newInstance(String identifier) {
		// TODO: throw an exception instead of returning null?
		return (Instance) createType(INSTANCE_TYPES, identifier);
	}

	// Sets the type used to generate FormatSupport instances for the given
	// workflow identifier.
	public static void registerFormatSupport(String identifier, Type type) {
		setFirstEntry(FORMAT_SUPPORT_TYPES, identifier, type);
	}

	// Returns a new FormatSupport instance for the given identifier, or null if
	// none is registered.
	public static FormatSupport getFormatSupport(String identifier) {
		return (FormatSupport) createType(FORMAT_SUPPORT_TYPES, identifier);
	}

	// Returns a set of identifiers for all registered workflows
	public static Set<String> getWorkflowIdentifiers() {
		return new Set<String>(INSTANCE_TYPES.keySet());
	}

	// (jonathan@) This feels a little hacky, but is the best way I can come up
	// with right now to ensure that we can have a singly-maintained registry
	// of all workflows, useful in building general tools around workflows.
	// This still gives individual classes fine-grained control over their
	// initialization, and does require two steps for an implementation to
	// become registered (see this class's toplevel doc), but has the advantage
	// that all other code which might need these initializations to happen can
	// be ignorant of the mechanism in which it happens.
	static {
		ShiftProcessingPipeline.loadWorkflows();
		ShiftWorkflowTesting.loadWorkflows();
		ShiftOpportunities.loadWorkflows();
	}
}