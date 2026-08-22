-- CreateTable
CREATE TABLE "_CategoryToProvider" (
    "A" TEXT NOT NULL,
    "B" TEXT NOT NULL,

    CONSTRAINT "_CategoryToProvider_AB_pkey" PRIMARY KEY ("A","B")
);

-- CreateIndex
CREATE INDEX "_CategoryToProvider_B_index" ON "_CategoryToProvider"("B");

-- AddForeignKey
ALTER TABLE "_CategoryToProvider" ADD CONSTRAINT "_CategoryToProvider_A_fkey" FOREIGN KEY ("A") REFERENCES "categories"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "_CategoryToProvider" ADD CONSTRAINT "_CategoryToProvider_B_fkey" FOREIGN KEY ("B") REFERENCES "providers"("id") ON DELETE CASCADE ON UPDATE CASCADE;
