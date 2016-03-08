//
//  RACUtils.swift
//  smalltalk
//
//  Created by Mikko Hämäläinen on 23/09/15.
//  Copyright (c) 2015 Mikko Hämäläinen. All rights reserved.
//

import ReactiveCocoa
import Result

private let defaultSessionError = NSError(domain: "org.reactivecocoa.ReactiveCocoa.rac_dataWithRequestBackgroundSupport", code: 1, userInfo: nil)

extension NSURLSession {
	/// Returns a producer that will execute the given request once for each
	/// invocation of start().
	public func rac_dataWithRequestBackgroundSupport(request: NSURLRequest) -> SignalProducer<(NSData, NSURLResponse), NSError> {
		return SignalProducer { observer, disposable in
			let backgroundTaskId = UIApplication.sharedApplication().beginBackgroundTaskWithExpirationHandler({})
			let task = self.dataTaskWithRequest(request) { data, response, error in
				if let data = data, response = response {
					observer.sendNext((data, response))
					observer.sendCompleted()
				} else {
					observer.sendFailed(error ?? defaultSessionError)
				}				
			}
			
			disposable.addDisposable {
				task.cancel()
				UIApplication.sharedApplication().endBackgroundTask(backgroundTaskId)
			}
			task.resume()
		}
	}
}

extension SignalProducerType {
	func discardError() -> SignalProducer<Value, NoError> {
		return flatMapError { _ in
			return SignalProducer<Value, NoError>.empty
		}
	}
	
	func merge<Value, Error>(signals: [SignalProducer<Value, Error>]) -> SignalProducer<Value, Error> {
		return SignalProducer<SignalProducer<Value, Error>, Error>(values: signals)
			.flatten(.Merge)
	}
	
	/// Delays `Next` and `Completed` events by the given interval after the first event has passed, forwarding
	/// them on the given scheduler.
	///
	/// `Error` and `Interrupted` events are always scheduled immediately.
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	public func throttleAfterFirst(interval: NSTimeInterval, onScheduler scheduler: DateSchedulerType) -> SignalProducer<Value, Error> {
		return lift { $0.throttleAfterFirst(interval, onScheduler: scheduler) }
	}
	
	/// Delays `Failed` events by the given interval, forwarding
	/// them on the given scheduler.
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	public func delayFailed(interval: NSTimeInterval, onScheduler scheduler: DateSchedulerType) -> SignalProducer<Value, Error> {
		return lift { $0.delayFailed(interval, onScheduler: scheduler) }
	}
	
	/// Ignores failures up to `count` times SLEEPING! between retries
	/// This is only safe if not done on main thread and even then it blocks a thread from the pool!
	/// Figure out how to do this with scheduler (naiive implementations do not work because this
	/// function NEEDS to return a signalProducer which is not possible with scheduleafter callback
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	public func unsafeSleepRetryWithDelay(count: Int, interval: NSTimeInterval, onScheduler scheduler: DateSchedulerType) -> SignalProducer<Value, Error> {
		precondition(count >= 0)
		
		if count == 0 {
			return producer
		} else {
			return flatMapError { _ in
				NSThread.sleepForTimeInterval(interval)
				return self.unsafeSleepRetryWithDelay(count - 1, interval: interval, onScheduler: scheduler)
			}
		}
	}
	
	/// Ignores failures up to `count` times.
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	public func retryWithDelay(count: Int, interval: NSTimeInterval, onScheduler scheduler: DateSchedulerType) -> SignalProducer<Value, Error> {
		precondition(count >= 0)
		
		if count == 0 {
			return producer
		} else {
			return delayFailed(interval, onScheduler: scheduler).flatMapError { _ in
				self.retryWithDelay(count - 1, interval: interval, onScheduler: scheduler)
			}
		}
	}
	
	//Ignore error up to N times with delay after each retry
	/*
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	public func retryWithDelay(count: Int, interval: NSTimeInterval, onScheduler scheduler: DateSchedulerType) -> SignalProducer<Value, Error> {
		precondition(count >= 0)
		if count == 0 {
			return producer
		} else {
			return flatMapError { _ in
				return SignalProducer { observer, compositeDisposable in
					compositeDisposable += scheduler.scheduleAfter(scheduler.currentDate.dateByAddingTimeInterval(interval)) {
						return self.retry(count - 1)
					}
				}
			}
		}
	}
	*/
	

	
	//Catches an error and translates into Result<NSError>
	/*
	func mapErrorToResult() -> SignalProducer<Result<Value, NSError>, NoError> {
		return flatMapError { error in
			return SignalProducer { observer, disposable in
				let eResult = Result<Value, NSError>(error: error)
				observer.sendNext(eResult)
				observer.sendCompleted()
			}
		}
	}
	*/
}

extension SignalType {
	/// Delays `Failed` events by the given interval, forwarding
	/// them on the given scheduler.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func delayFailed(interval: NSTimeInterval, onScheduler scheduler: DateSchedulerType) -> Signal<Value, Error> {
		precondition(interval >= 0)
		
		return Signal { observer in
			return self.observe { event in
				switch event {
				case .Failed:
					let date = scheduler.currentDate.dateByAddingTimeInterval(interval)
					scheduler.scheduleAfter(date) {
						observer.action(event)
					}
				default:
					scheduler.schedule {
						observer.action(event)
					}
				}
			}
		}
	}
	
	
	/// Delays `Next` and `Completed` events by the given interval after the first event has passed, forwarding
	/// them on the given scheduler.
	///
	/// `Error` and `Interrupted` events are always scheduled immediately.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func throttleAfterFirst(interval: NSTimeInterval, onScheduler scheduler: DateSchedulerType) -> Signal<Value, Error> {
		precondition(interval >= 0)
		
		return Signal { observer in
			var cumulativeInterval = NSTimeInterval(0)
			return self.observe { event in
				switch event {
				case .Failed, .Interrupted:
					//scheduler.schedule { //DELAY has this but not sure why
						observer.action(event)
					//}
					
				default:
					let date = scheduler.currentDate.dateByAddingTimeInterval(cumulativeInterval)
					scheduler.scheduleAfter(date) {
						observer.action(event)
					}
					cumulativeInterval += interval
				}
			}
		}
	}
	
	func toSignalProducer() -> SignalProducer<Value, Error> {
		return SignalProducer {
			(observer, disposable) in
			let disp = self.observe(Signal.Observer { event in
				switch event {
				case let .Next(next):
					observer.sendNext(next)
				case let .Failed(error):
					observer.sendFailed(error)
				case .Interrupted:
					observer.sendInterrupted()
				case .Completed:
					observer.sendCompleted()
				}
				})
			
			disposable.addDisposable(disp)
		}
	}
}

//From Rex (github)

extension SignalType {
	
	/// Applies `transform` to values from `signal` with non-`nil` results unwrapped and
	/// forwared on the returned signal.
	public func filterMap<U>(transform: Value -> U?) -> Signal<U, Error> {
		return Signal<U, Error> { observer in
			return self.observe(Observer(next: { value in
				if let val = transform(value) {
					observer.sendNext(val)
				}
				}, failed: { error in
					observer.sendFailed(error)
				}, completed: {
					observer.sendCompleted()
				}, interrupted: {
					observer.sendInterrupted()
			}))
		}
	}
	
	/// Returns a signal that drops `Error` sending `replacement` terminal event
	/// instead, defaulting to `Completed`.
	public func ignoreError(replacement replacement: Event<Value, NoError> = .Completed) -> Signal<Value, NoError> {
		precondition(replacement.isTerminating)
		
		return Signal<Value, NoError> { observer in
			return self.observe { event in
				switch event {
				case let .Next(value):
					observer.sendNext(value)
				case .Failed:
					observer.action(replacement)
				case .Completed:
					observer.sendCompleted()
				case .Interrupted:
					observer.sendInterrupted()
				}
			}
		}
	}
	
	/// Forwards events from `signal` until `interval`. Then if signal isn't completed yet,
	/// terminates with `event` on `scheduler`.
	///
	/// If the interval is 0, the timeout will be scheduled immediately. The signal
	/// must complete synchronously (or on a faster scheduler) to avoid the timeout.
	public func timeoutAfter(interval: NSTimeInterval, withEvent event: Event<Value, Error>, onScheduler scheduler: DateSchedulerType) -> Signal<Value, Error> {
		precondition(interval >= 0)
		precondition(event.isTerminating)
		
		return Signal { observer in
			let disposable = CompositeDisposable()
			
			let date = scheduler.currentDate.dateByAddingTimeInterval(interval)
			disposable += scheduler.scheduleAfter(date) {
				observer.action(event)
			}
			
			disposable += self.observe(observer)
			return disposable
		}
	}
}

extension SignalType where Value: SequenceType {
	/// Returns a signal that flattens sequences of elements. The inverse of `collect`.
	public func uncollect() -> Signal<Value.Generator.Element, Error> {
		return Signal<Value.Generator.Element, Error> { observer in
			return self.observe { event in
				switch event {
				case let .Next(sequence):
					sequence.forEach { observer.sendNext($0) }
				case let .Failed(error):
					observer.sendFailed(error)
				case .Completed:
					observer.sendCompleted()
				case .Interrupted:
					observer.sendInterrupted()
				}
			}
		}
	}
}

extension SignalProducerType {
	
	/// Buckets each received value into a group based on the key returned
	/// from `grouping`. Termination events on the original signal are
	/// also forwarded to each producer group.
	public func groupBy<Key: Hashable>(grouping: Value -> Key) -> SignalProducer<(Key, SignalProducer<Value, Error>), Error> {
		return SignalProducer<(Key, SignalProducer<Value, Error>), Error> { observer, disposable in
			var groups: [Key: Signal<Value, Error>.Observer] = [:]
			
			let lock = NSRecursiveLock()
			lock.name = "me.neilpa.rex.groupBy"
			
			self.start(Observer(next: { value in
				let key = grouping(value)
				
				lock.lock()
				var group = groups[key]
				if group == nil {
					let (producer, sink) = SignalProducer<Value, Error>.buffer()
					observer.sendNext(key, producer)
					
					groups[key] = sink
					group = sink
				}
				lock.unlock()
				
				group!.sendNext(value)
				
				}, failed: { error in
					observer.sendFailed(error)
					groups.values.forEach { $0.sendFailed(error) }
					
				}, completed: { _ in
					observer.sendCompleted()
					groups.values.forEach { $0.sendCompleted() }
					
				}, interrupted: { _ in
					observer.sendInterrupted()
					groups.values.forEach { $0.sendInterrupted() }
			}))
		}
	}
	
	/// Applies `transform` to values from self with non-`nil` results unwrapped and
	/// forwared on the returned producer.
	public func filterMap<U>(transform: Value -> U?) -> SignalProducer<U, Error> {
		return lift { $0.filterMap(transform) }
	}
	
	/// Returns a producer that drops `Error` sending `replacement` terminal event
	/// instead, defaulting to `Completed`.
	public func ignoreError(replacement replacement: Event<Value, NoError> = .Completed) -> SignalProducer<Value, NoError> {
		precondition(replacement.isTerminating)
		return lift { $0.ignoreError(replacement: replacement) }
	}
	
	/// Forwards events from self until `interval`. Then if producer isn't completed yet,
	/// terminates with `event` on `scheduler`.
	///
	/// If the interval is 0, the timeout will be scheduled immediately. The producer
	/// must complete synchronously (or on a faster scheduler) to avoid the timeout.
	public func timeoutAfter(interval: NSTimeInterval, withEvent event: Event<Value, Error>, onScheduler scheduler: DateSchedulerType) -> SignalProducer<Value, Error> {
		return lift { $0.timeoutAfter(interval, withEvent: event, onScheduler: scheduler) }
	}
}

extension SignalProducerType where Value: SequenceType {
	/// Returns a producer that flattens sequences of elements. The inverse of `collect`.
	public func uncollect() -> SignalProducer<Value.Generator.Element, Error> {
		return lift { $0.uncollect() }
	}
}
