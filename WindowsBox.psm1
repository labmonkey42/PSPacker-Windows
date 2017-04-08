using module PSPacker

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
