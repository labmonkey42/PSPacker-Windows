using module .\PSPacker\Machine.psm1

Class WindowsMachine : Machine
{
    
    WindowsMachine()
    {
        $mytype = $this.GetType()
        if ($mytype -eq [WindowsMachine])
        {
            throw("Class $mytype is abstract and must be implemented")
        }
    }

}
