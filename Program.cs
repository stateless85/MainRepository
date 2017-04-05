using System;
using DotNetApp.Model;

namespace ConsoleApplication
{
public class Game
{
    public int _val;
    public Game(int i)
    {
        this._val = i;
    }
    public string GetPosition(int i)
    {
        return "Position " + i.ToString();
    }
}
    public class Program
    {
           public static byte[] GetBytesDouble( double argument )
    {
        byte[] byteArray = BitConverter.GetBytes( argument );

        return byteArray;
    }

        public static void Main(string[] args)
        {
            Car c = new SportCar();
            
            c.ShowCar();
            c.Accelerate();
            c.ShowCar();

            Console.WriteLine("Hello World! ");
        }
    }
}
