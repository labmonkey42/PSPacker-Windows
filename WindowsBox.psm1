using module .\PSPacker\Box.psm1

Class WindowsBox : Box
{

    WindowsBox()
    {
        $mytype = $this.GetType()
        if ($mytype -eq [WindowsBox])
        {
            throw("Class $mytype is abstract and must be implemented")
        }
    }

}
