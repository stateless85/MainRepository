using System;
namespace DotNetApp.Model
{
    public abstract class Car
    {
        public int speed {get; protected set;} = 10;
        public int acceleration {get; protected set;} = 25;

        public virtual void ShowCar()
        {
            Console.WriteLine("Base Speed {0}, acceleration {1}", speed, acceleration);
        }

        public void Accelerate()
        {
            speed += acceleration;
        }
    }

public class SportCar : Car
{
public int value = 0;


 public override void ShowCar()
 {
     Console.WriteLine("Sport Car Speed {0}, acceleration {1}", speed, acceleration);
 }
}

public class MiniCar : Car
{
 public override void ShowCar()
 {
     Console.WriteLine("Mini Car Speed {0}, acceleration {1}", speed, acceleration);
 }
}

}