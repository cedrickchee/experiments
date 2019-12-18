# Abstract Base Class example

"""Example 1"""
from abc import ABC, abstractmethod


class Polygon(ABC):
    # abstract method
    @abstractmethod
    def no_of_sides(self):
        pass


class Square(Polygon):
    # overriding abstract method
    def no_of_sides(self):
        print("I have 4 sides")


class Hexagon(Polygon):
    # overriding abstract method
    def no_of_sides(self):
        print("I have 6 sides")


class Pentagon(Polygon):
    # overriding abstract method
    def no_of_sides(self):
        print("I have 5 sides")


# Driver code
square = Square()
square.no_of_sides()

hexagon = Hexagon()
hexagon.no_of_sides()

"""Example 2: Concrete Methods in Abstract Base Classes"""


class Animal(ABC):
    @abstractmethod
    def move(self):
        print("I can move")


class Cat(Animal):
    def move(self):
        super().move()
        print("I can meow")


# Driver code
cat = Cat()
cat.move()

"""Example 3: Abstract Properties"""
import abc


class parent(ABC):
    @abc.abstractproperty
    def geeks(self):
        return "parent class"


class child(parent):
    @property
    def geeks(self):
        return "child class"


try:
    p = parent()
    print(p.geeks)
except Exception as err:
    print("Exception:", err)

c = child()
print(c.geeks)
