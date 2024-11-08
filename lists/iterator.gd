class_name Iterator
extends Resource

## Iterator base class for iterating over a collection
var name: String

## Generic container class for managing instances of type [T]
var elements: Array:
	set(value):
		elements = value 
		end = elements.size()
	get:
		return elements

const START: int = 0
var current: int
var end: int
const INCREMENT = 1

## Initialize the Iterator with a collection
func _init(collection: Array = []) -> void:
	elements = collection
	current = START

## Should be able to be used like Array.any() method
func any(method: Callable) -> bool:
	for element in elements:
		if method.call(element):
			return true
	return false

## Filter the elements based on a condition
func filter(method: Callable) -> Iterator:
	var filtered = elements.filter(method)
	return Iterator.new(filtered)

## Reduce the elements to a single value
func reduce(method: Callable, initial_value = null) -> Variant:
	return elements.reduce(method, initial_value)

## Sort the elements using a custom sorting function
func sort_custom(method: Callable) -> Iterator:
	var sorted = elements.duplicate()
	sorted.sort_custom(method)
	return Iterator.new(sorted)

## Map the elements to a new form
func map(method: Callable) -> Iterator:
	var mapped = elements.map(method)
	return Iterator.new(mapped)

## Check if the iteration should continue
func should_continue() -> bool:
	return (current < end)

func _iter() -> Iterator:
	return Iterator.new(elements)

## Initialize the iterator for iteration
func _iter_init(_arg: Variant) -> bool:
	current = START
	end = elements.size()
	return should_continue()

## Get the next item in the iteration
func _iter_next(_arg: Variant) -> bool:
	current += INCREMENT
	return should_continue()

## Get the current item in the iteration
func _iter_get(_arg: Variant) -> Variant:
	return elements[current]

func append(element: Variant) -> void:
	elements.append(element)

## Returns the count of elements
func size() -> int:
	return elements.size()

func is_empty() -> bool:
	return elements.is_empty()

## Get the first element
func front() -> Variant:
	return elements.front() if not is_empty() else null

## Get the last element
func back() -> Variant:
	return elements.back() if not is_empty() else null

## Get a slice of the elements
func slice(begin: int, _end: int = -1, step: int = 1, deep: bool = false) -> Iterator:
	var sliced = elements.slice(begin, _end, step, deep)
	return Iterator.new(sliced)

## Find the index of an element
func find(what: Variant, from: int = 0) -> int:
	return elements.find(what, from)

## Check if the iterator contains an element
func has(element: Variant) -> bool:
	return element in elements

## Clear all elements
func clear() -> void:
	elements.clear()
	end = 0
	
func to_array() -> Array:
	var a: Array = []
	for element in elements:
		a.append(element)
	return a
	
## Join all elements into a string, separated by the given delimiter
## Returns an empty string if the iterator is empty
## Non-string elements will be converted using str()
func array_to_string(delimiter: String = ", ") -> String:
	if is_empty():
		return ""
	
	var string_elements: Array = elements.map(func(element): return str(element))
	return delimiter.join(string_elements)
